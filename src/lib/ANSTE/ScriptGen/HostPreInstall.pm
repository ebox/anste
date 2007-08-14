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

package ANSTE::ScriptGen::HostPreInstall;

use strict;
use warnings;

use ANSTE::Image::Image;
use ANSTE::Config;
use ANSTE::Exceptions::MissingArgument;
use ANSTE::Exceptions::InvalidType;
use ANSTE::Exceptions::InvalidFile;

sub new # (image) returns new HostInstallGen object
{
	my ($class, $image) = @_;
	my $self = {};

    defined $image or
        throw ANSTE::Exceptions::MissingArgument('image');

    if (not $image->isa('ANSTE::Image::Image')) {
        throw ANSTE::Exceptions::InvalidType('image',
                                             'ANSTE::Image::Image');
    }

    $self->{hostname} = $image->name();
    $self->{ip} = $image->ip();
    my $system = ANSTE::Config->instance()->system();

    eval("use ANSTE::System::$system");
    die "Can't load package $system: $@" if $@;

    $self->{system} = "ANSTE::System::$system"->new();
	
	bless($self, $class);

	return $self;
}

sub writeScript # (file)
{
	my ($self, $file) = @_;

    defined $file or
        throw ANSTE::Exceptions::MissingArgument('file');
       
    if (not -w $file) {
        throw ANSTE::Exceptions::InvalidFile('file');
    }

    my $hostname = $self->{hostname};

	print $file "#!/bin/sh\n";
	print $file "\n# Hostname configuration file\n";
	print $file "# Generated by ANSTE for host $hostname\n\n"; 

    print $file "# Receives the mount point of the image as an argument\n";
    print $file 'MOUNT=$1'."\n\n";

    $self->_writeHostnameConfig($file);
    $self->_writeHostsConfig($file);
	$self->_writeInitialNetworkConfig($file);
    $self->_writeMasterAddress($file);
}

sub _writeHostnameConfig # (file)
{
    my ($self, $file) = @_;

    my $system = $self->{system};

    print $file "# Write hostname config\n";
    my $config = $system->hostnameConfig($self->{hostname});
    print $file "$config\n\n";
}

sub _writeHostsConfig # (file)
{
    my ($self, $file) = @_;

    my $system = $self->{system};
    my $host = $self->{hostname};

    print $file "# Write hosts configuration\n";
    my $config = $system->hostsConfig($host);
    print $file "$config\n\n";
}

sub _writeInitialNetworkConfig # (file)
{
	my ($self, $file) = @_;

    my $system = $self->{system};
	my $ip = $self->{ip};

    my $config = $system->initialNetworkConfig($ip);

	print $file "# Write initial network configuration\n";
    print $file "$config\n\n";
}

sub _writeMasterAddress # (file)
{
	my ($self, $file) = @_;

    my $system = $self->{system};

    my $config = ANSTE::Config->instance();
    my $port = $config->masterPort();
    # TODO: Not sure if this is correct
    my $masterIP = $config->gateway();
    my $MASTER = "http://$masterIP:$port";

    print $file "# Stores the master address so anste-slave can read it\n";
    my $command = $system->storeMasterAddress($MASTER);
    print $file "$command\n";
}

1;
