# Copyright (C) 2007 José Antonio Calvo Fernández <jacalvo@warp.es> 
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License, version 2, as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

package ANSTE::Deploy::HostDeployer;

use strict;
use warnings;

use ANSTE::Scenario::Host;
use ANSTE::ScriptGen::HostImageSetup;
use ANSTE::Comm::MasterClient;
use ANSTE::Comm::MasterServer;
use ANSTE::Comm::HostWaiter;
use ANSTE::Image::Image;
use ANSTE::Image::Commands;
use ANSTE::Image::Creator;
use ANSTE::Config;
use ANSTE::Exceptions::MissingArgument;
use ANSTE::Exceptions::InvalidType;

use threads;
use threads::shared;
use Error qw(:try);

my $lockMount : shared;

# Class: HostDeployer
#
#   Deploys a host virtual machine in a separate thread.
#   The operations are done with the classes in <ANSTE::Image> module.
#

# Constructor: new
#
#   Constructor for HostDeployer class.
#   Initializes the object with the given host representation object and
#   the given IP address for the communications interface.
#
# Parameters:
#
#   host - <ANSTE::Scenario::Host> object.
#   ip - IP address to be assigned.
#
# Returns:
#
#   A recently created <ANSTE::Deploy::HostDeployer> object.
#
sub new # (host, ip) returns new HostDeployer object
{
	my ($class, $host, $ip) = @_;
	my $self = {};

    defined $host or
        throw ANSTE::Exceptions::MissingArgument('host');
    defined $ip or
        throw ANSTE::Exceptions::MissingArgument('ip');

    if (not $host->isa('ANSTE::Scenario::Host')) {
        throw ANSTE::Exception::InvalidType('host',
                                            'ANSTE::Scenario::Host');
    }

    my $config = ANSTE::Config->instance();
    my $system = $config->system();
    my $virtualizer = $config->virtualizer();

    eval "use ANSTE::System::$system";
    die "Can't load package $system: $@" if $@;

    eval "use ANSTE::Virtualizer::$virtualizer";
    die "Can't load package $virtualizer: $@" if $@;

    $self->{system} = "ANSTE::System::$system"->new();
    $self->{virtualizer} = "ANSTE::Virtualizer::$virtualizer"->new();

    my $hostname = $host->name();
    my $memory = $host->memory();
    if (not $memory) {
        $memory = $host->baseImage()->memory();
    }
    my $swap = $host->baseImage()->swap();
    my $image = new ANSTE::Image::Image(name => $hostname,
                                        memory => $memory,
                                        swap => $swap,
                                        ip => $ip);
    $image->setNetwork($host->network());

    my $cmd = new ANSTE::Image::Commands($image);

	$self->{host} = $host;
    $self->{image} = $image;
    $self->{cmd} = $cmd;
    $self->{ip} = $ip;

    my $foo = $host->network()->interfaces()->[0]->address();

	bless($self, $class);

	return $self;
}

# Method: host
#
#   Gets the the host object.
#
# Returns:
#
#   ref - <ANSTE::Scenario::Host> object.
#
sub host # returns ref
{
    my ($self) = @_;

    return $self->{host};
}

# Method: ip
#
#   Gets the IP address assigned to the object's host.
#
# Returns:
#
#   string - contains the IP address
#
sub ip # returns ip string
{
    my ($self) = @_;

    return $self->{ip};
}

# Method: startDeployThread
#
#   Starts the deploying thread for the object's host.
#
# Returns:
#
#   ref - Reference to the created thread.
#
# Exceptions:
#
#   <ANSTE::Exceptions::MissingArgument> - throw if parameter is not present
#
sub startDeployThread
{
    my ($self, $ip) = @_;

    $self->{thread} = threads->create('_deploy', $self);
}

# Method: waitForFinish
#
#   Waits until the deploying thread finishes.
#
sub waitForFinish
{
    my ($self) = @_;
    
    $self->{thread}->join();
}

# Method: shutdown
#
#   Shuts down the image and virtual machine creation.
#
sub shutdown
{
    my ($self) = @_;

    my $cmd = $self->{cmd};

    $cmd->shutdown();
}

# Method: destroy
#
#   Stops immediately the virtual machine of the host.
#
sub destroy
{
    my ($self) = @_;

    my $cmd = $self->{cmd};

    $cmd->destroy();
}

# Method: deleteImage
#
#   Deletes the image of the deployed host.
#
sub deleteImage
{
    my ($self) = @_;

    my $virtualizer = $self->{virtualizer};

    my $host = $self->{host};
    my $hostname = $host->name();

    print "[$hostname] Deleting image...\n";
    $virtualizer->deleteImage($hostname);
    print "[$hostname] Image deleted.\n";
}

sub _deploy
{
    my ($self) = @_;

    my $system = $self->{system};

    my $image = $self->{image};
    my $cmd = $self->{cmd};

    my $host = $self->{host};
    my $hostname = $host->name();
    my $ip = $image->ip();

    my $config = ANSTE::Config->instance();

    # Add communications interface
    my $commIface = $image->commInterface();
    # This gateway is not needed anymore
    # and may conflict with the real one.
    $commIface->removeGateway() unless $host->isRouter();
    unshift(@{$host->network()->interfaces()}, $commIface);

    print "[$hostname] Creating a copy of the base image...\n";
    try {
        $self->_copyBaseImage() or die "Can't copy base image";
    } catch ANSTE::Exceptions::NotFound with {
        print "[$hostname] Base image not found, can't continue.";
        return(-1);
    };

    # Critical section here to prevent mount errors with loop device busy
    { 
        lock($lockMount);
        print "[$hostname] Updating hostname on the new image...\n";
        try {
            my $ok = $self->_updateHostname();
            if (not $ok) {
                print "[$hostname] Error copying host files.\n";
                return;                
            }
        } catch Error with {
            my $err = shift;
            my $msg = $err->stringify();
            print "[$hostname] ERROR: $msg\n";
            return;
        };
    };

    print "[$hostname] Creating virtual machine ($ip)...\n"; 
    $cmd->createVirtualMachine();

    try {

        # Execute pre-install scripts
        my $pre = $host->preScripts();
        if (@{$pre}) {
            print "[$hostname] Executing pre scripts...\n";
            $cmd->executeScripts($pre);
        }

        my $setupScript = "$hostname-setup.sh";
        print "[$hostname] Generating setup script...\n";
        $self->_generateSetupScript($setupScript);
        $self->_executeSetupScript($ip, $setupScript);

        # It worths it stays here in order to be able to use pre/post-install
        # scripts as well. This permits us to move trasferred file,
        # change their rights and so on.
        my $list = $host->{files}->list(); # retrieve files list
        print "[$hostname] Transferring files...";
        $cmd->transferFiles($list);
        print "... done\n";

        # NAT with this address is not needed anymore
        my $iface = $config->natIface();
        $system->disableNAT($iface, $commIface->address());
        # Adding the new nat rule
        my $interfaces = $host->network()->interfaces();
        foreach my $if (@{$interfaces}) {
            if ($if->gateway() eq $config->gateway()) {
                $system->enableNAT($iface, $if->address());
                last;
            }
        }

        # Execute post-install scripts
        my $post = $host->postScripts();
        if (@{$post}) {
            print "[$hostname] Executing post scripts...\n";
            $cmd->executeScripts($post);
        }        
    } catch ANSTE::Exceptions::Error with {
        my $ex = shift;
        my $msg = $ex->message();
        print "[$hostname] ERROR: $msg\n";
    } catch Error with {
        my $err = shift;
        my $msg = $err->stringify();
        print "[$hostname] ERROR: $msg\n";
    };
}

sub _copyBaseImage
{
    my ($self) = @_;

    my $virtualizer = $self->{virtualizer};

    my $host = $self->{host};

    my $baseimage = $host->baseImage();
    my $newimage = $self->{image}; 

    $virtualizer->createImageCopy($baseimage, $newimage);
}

sub _updateHostname # returns boolean
{
    my ($self) = @_;

    my $cmd = $self->{cmd};
    
    my $ok = 0;

    try {
        $cmd->mount() or die "Can't mount image: $!";
    } catch Error with {
        $cmd->deleteMountPoint();
        die "Can't mount image.";
    };

    try {
        $cmd->copyHostFiles() or die "Can't copy files: $!";
        $ok = 1;
    } finally {
        $cmd->umount() or die "Can't unmount image: $!";
    };

    return $ok;
}

sub _generateSetupScript # (script)
{
    my ($self, $script) = @_;
    
    my $host = $self->{host};
    my $hostname = $host->name();

    my $generator = new ANSTE::ScriptGen::HostImageSetup($host);
    my $FILE;
    open($FILE, '>', $script) 
        or throw ANSTE::Exceptions::Error("Can't open file $script: $!");
    $generator->writeScript($FILE);
    close($FILE) 
        or throw ANSTE::Exceptions::Error("Can't close file $script: $!");
}

sub _executeSetupScript # (host, script)
{
    my ($self, $host, $script) = @_;

    my $system = $self->{system};

    my $client = new ANSTE::Comm::MasterClient;
    my $waiter = ANSTE::Comm::HostWaiter->instance();
    my $config = ANSTE::Config->instance();

    my $PORT = $config->anstedPort(); 
    $client->connect("http://$host:$PORT");

    my $verbose = $config->verbose();

    my $hostname = $self->{host}->name();

    print "[$hostname] Executing setup script...\n" if $verbose;
    $client->put($script) or print "Upload failed\n";
    $client->exec($script, "$script.out") or print "Failed\n";
    my $ret = $waiter->waitForExecution($hostname);
    print "[$hostname] Setup script finished (Return value = $ret).\n";

    if ($verbose) {
        print "[$hostname] Script executed with the following output:\n";
        $client->get("$script.out");
        $self->_printOutput($hostname, "$script.out");
    }

    print "[$hostname] Deleting generated files...\n" if $verbose;
    $client->del($script);
    $client->del("$script.out");
    unlink($script);
    unlink("$script.out") if $verbose;
}

sub _printOutput # (hostname, file)
{
    my ($self, $hostname, $file) = @_;

    my $FILE;
    open($FILE, '<', $file) or die "Can't open file $file: $!";
    my @lines = <$FILE>;
    foreach my $line (@lines) {
        print "[$hostname] $line";
    }
    print "\n";
    close($FILE) or die "Can't close file $file: $!";
}

1;
