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

package ANSTE::Comm::MasterClient;

use strict;
use warnings;

use ANSTE::Config;
use ANSTE::Exceptions::MissingArgument;
use ANSTE::Exceptions::InvalidFile;

use SOAP::Lite; # +trace => 'debug'; 

use constant URI => 'urn:ANSTE::Comm::SlaveServer';

# Class: MasterClient
# 
#   Client that runs on the master host and send commands
#   to the slave hosts.
#

# Constructor: new
#
#   Constructor for MasterClient class.
#
# Returns:
#
#   A recently created <ANSTE::Comm:MasterClient> object.
#
sub new
{
    my ($class) = @_;
    my $self = {};

    $self->{soap} = undef;

    bless $self, $class;

    return $self;
}

# Method: connect
#
#   Initialize the object used to send the commands with
#   the location of the server.
#
# Parameters:
#
#   url - URL of the server.
#
# Exceptions:
#
#   <ANSTE::Exceptions::MissingArgument> - throw if argument not present
#
sub connect	# (url) 
{
    my ($self, $url) = @_;

    defined $url or
        throw ANSTE::Exceptions::MissingArgument('url');

    $self->{soap} = new SOAP::Lite(uri => URI,
                                   proxy => $url,
                                   endpoint => $url); 
}

# Method: connected
#
#   Check if the client is connected.
#
# Returns:
#
#   boolean - true if the client have a valid connection with the server
#
sub connected # returns boolean
{
    my ($self) = @_;

    return defined($self->{soap});
}

# Method: put
#
#   Sends a file to the slave host.
#
# Parameters:
#
#   file - String with the name of the file.
#
# Returns:
#
#   boolean - true if the server response is OK, false otherwise
#
# Exceptions:
#
#   <ANSTE::Exceptions::MissingArgument> - throw if argument not present
#   <ANSTE::Exceptions::InvalidFile> - throw if file does not exist
#
sub put	# (file) returns boolean
{
    my ($self, $file) = @_;

    defined $file or
        throw ANSTE::Exceptions::MissingArgument('file');

    if (not -r $file) {
        throw ANSTE::Exceptions::InvalidFile('file');
    }

    my $soap = $self->{soap};

    my $size = -s $file;
    # Reads the data
    my $FILE;
    open($FILE, '<', $file) or die "Can't open(): $!";
    my $content;
    read($FILE, $content, $size);
    close($FILE);

    my $response = $soap->put(SOAP::Data->name('name' => $file),
		                      SOAP::Data->name('content' => $content));
    if ($response->fault) {
    	die "SOAP request failed: $!";
    }
    my $result = $response->result;
    return($result eq 'OK');
}

# Method: get
#
#   Sends a file get request to the server and writes the response to disk.
#
# Parameters:
#
#   file - String with the name of the file.
#
# Returns:
#
#   boolean - true if the server response is OK, false otherwise
#
# Exceptions:
#
#   <ANSTE::Exceptions::MissingArgument> - throw if argument not present
#
sub get	# (file)
{
    my ($self, $file) = @_;

    defined $file or
        throw ANSTE::Exceptions::MissingArgument('file');

    my $soap = $self->{soap};
    my $config = ANSTE::Config->instance();

    # Sends the request 
    my $response = $soap->get(SOAP::Data->name('name' => $file));
    if ($response->fault) {
    	die "SOAP request failed: $!";
    }
    my $content = $response->result;
    if ($content eq 'ERR'){
        return 0;
    } else {
    	# Writes the file
        my $FILE;
    	open($FILE, ">", $file) or die "Can't open(): $!";
    	print $FILE $content;
    	close $FILE;
        return 1;
    }
}

# Method: exec
#
#   Sends a command execution requests to the server.
#
# Parameters:
#
#   command - String with the name of the command.
#   log     - *optional* String with the name of the log file.
#
# Returns:
#
#   boolean - true if the server response is OK, false otherwise
#
# Exceptions:
#
#   <ANSTE::Exceptions::MissingArgument> - throw if argument not present
#
sub exec # (command, log) # - log optional
{
    my ($self, $command, $log) = @_;

    defined $command or
        throw ANSTE::Exceptions::MissingArgument('command');

    my $soap = $self->{soap};

    my @args = (SOAP::Data->name('name' => $command));
    if (defined($log)) {
        push(@args, SOAP::Data->name('log' => $log));
    }
    my $response = $soap->exec(@args);
    if ($response->fault) {
    	die "SOAP request failed: $!";
    }
    my $result = $response->result;
    return($result eq 'OK');
}

# Method: del
#
#   Sends a file deletion request to the server.
#
# Parameters:
#
#   file - String with the name of the file to be deleted.
#
# Returns:
#
#   boolean - true if the server response is OK, false otherwise
#
# Exceptions:
#
#   <ANSTE::Exceptions::MissingArgument> - throw if argument not present
#
sub del	# (file)
{
    my ($self, $file) = @_;

    defined $file or
        throw ANSTE::Exceptions::MissingArgument('file');

    my $soap = $self->{soap};

    my $response = $soap->del(SOAP::Data->name('name' => $file));
    if ($response->fault) {
    	die "SOAP request failed: $!";
    }
    my $result = $response->result;
    return($result eq 'OK');
}

1;
