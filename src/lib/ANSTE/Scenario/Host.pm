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

package ANSTE::Scenario::Host;

use strict;
use warnings;

use ANSTE::Scenario::BaseImage;
use ANSTE::Scenario::Network;
use ANSTE::Scenario::Packages;
use ANSTE::Scenario::Files;
use ANSTE::Exceptions::MissingArgument;
use ANSTE::Exceptions::InvalidType;
use ANSTE::Config;

use XML::DOM;
use Perl6::Junction qw(any);

# Class: Host
#
#   Contains the information for a host of a scenario.
#

# Constructor: new
#
#   Constructor for Host class.
#
# Returns:
#
#   A recently created <ANSTE::Scenario::Host> object.
#
sub new # returns new Host object
{
	my $class = shift;
	my $self = {};

	$self->{name} = '';
	$self->{desc} = '';
	$self->{type} = 'none';
    $self->{baseImage} = new ANSTE::Scenario::BaseImage;
    $self->{network} = new ANSTE::Scenario::Network;
    $self->{packages} = new ANSTE::Scenario::Packages;
    $self->{files} = new ANSTE::Scenario::Files;
    $self->{'pre-scripts'} = [];
    $self->{'post-scripts'} = [];
    $self->{scenario} = undef;
    $self->{precondition} = 1;

	bless($self, $class);

	return $self;
}

# Method: name
#
#   Gets the name of the host.
#
# Returns:
#
#   string - contains the host name
#
sub name # returns name string
{
	my ($self) = @_;

	return $self->{name};
}

# Method: setName
#
#   Sets the name of the host.
#
# Parameters:
#
#   name - String with the name of the host.
#
# Exceptions:
#
#   <ANSTE::Exceptions::MissingArgument> - throw if argument is not present
#
sub setName # name string
{
	my ($self, $name) = @_;

    defined $name or
        throw ANSTE::Exceptions::MissingArgument('name');

	$self->{name} = $name;
}

# Method: desc
#
#   Gets the description of the host.
#
# Returns:
#
#   string - contains the host description
#
sub desc # returns desc string
{
	my ($self) = @_;
	return $self->{desc};
}

# Method: setDesc
#
#   Sets the description of the host.
#
# Parameters:
#
#   desc - String with the description of the host.
#
# Exceptions:
#
#   <ANSTE::Exceptions::MissingArgument> - throw if argument is not present
#
sub setDesc # desc string
{
	my ($self, $desc) = @_;

    defined $desc or
        throw ANSTE::Exceptions::MissingArgument('desc');

	$self->{desc} = $desc;
}

# Method: isRouter
#
#   Checks if the host simulates a router.
#
# Returns:
#
#   boolean - true if it's a router, false if not
#
sub isRouter # returns boolean
{
    my ($self) = @_;

    return $self->{type} =~ /router/;
}

# Method: type
#
#   Gets the type of the host.
#   Current types: none, router, dhcp-router, pppoe-router
#
# Returns:
#
#   string - type of the host
#
sub type # returns string
{
    my ($self) = @_;

    return $self->{type};
}

# Method: memory
#
#   Gets the memory size string.
#
# Returns:
#
#   string - contains the memory size
#
sub memory # returns memory string
{
	my ($self) = @_;

	return $self->{memory};
}

# Method: setMemory
#
#   Sets the memory size string.
#
# Parameters:
#
#   memory - String with the memory size.
#
# Exceptions:
#
#   <ANSTE::Exceptions::MissingArgument> - throw if argument is not present
#
sub setMemory # (memory)
{
	my ($self, $memory) = @_;

    defined $memory or
        throw ANSTE::Exceptions::MissingArgument('memory');

	$self->{memory} = $memory;
}

# Method: baseImage
#
#   Gets the object with the information of the base image of the host.
#
# Returns:
#
#   ref - <ANSTE::Scenario::BaseImage> object.
#
sub baseImage # returns BaseImage object
{
	my ($self) = @_;

	return $self->{baseImage};
}

# Method: setBaseImage
#
#   Sets the object with the information of the base image of the host.
#
# Parameters:
#
#   baseImage - <ANSTE::Scenario::BaseImage> object.
#
# Exceptions:
#
#   <ANSTE::Exceptions::MissingArgument> - throw if argument is not present
#   <ANSTE::Exceptions::InvalidType> - throw if argument has wrong type
#
sub setBaseImage # (baseImage)
{
	my ($self, $baseImage) = @_;

    defined $baseImage or
        throw ANSTE::Exceptions::MissingArgument('baseImage');

    if (not $baseImage->isa('ANSTE::Scenario::BaseImage')) {
        throw ANSTE::Exceptions::InvalidType('baseImage',
                                             'ANSTE::Scenario::BaseImage');
    }

	$self->{baseImage} = $baseImage;
}

# Method: network
#
#   Gets the object with the network configuration for the host.
#
# Returns:
#
#   ref - <ANSTE::Scenario::Network> object.
#
sub network # returns Network object
{
	my ($self) = @_;

	return $self->{network};
}

# Method: setNetwork
#
#   Sets the object with the network configuration for the host.
#
# Parameters:
#
#   network - <ANSTE::Scenario::Network> object.
#
# Exceptions:
#
#   <ANSTE::Exceptions::MissingArgument> - throw if argument is not present
#   <ANSTE::Exceptions::InvalidType> - throw if argument has wrong type
#
sub setNetwork # (network)
{
	my ($self, $network) = @_;

    defined $network or
        throw ANSTE::Exceptions::MissingArgument('network');

    if (not $network->isa('ANSTE::Scenario::Network')) {
        throw ANSTE::Exceptions::InvalidType('network',
                                             'ANSTE::Scenario::Network');
    }

	$self->{network} = $network;
}

# Method: packages
#
#   Gets the object with the information of packages to be installed.
#
# Returns:
#
#   ref - <ANSTE::Scenario::Packages> object.
#
sub packages # returns Packages object
{
	my ($self) = @_;

	return $self->{packages};
}

# Method: setPackages
#
#   Sets the object with the information of packages to be installed.
#
# Parameters:
#
#   packages - <ANSTE::Scenario::Packages> object.
#
# Exceptions:
#
#   <ANSTE::Exceptions::MissingArgument> - throw if argument is not present
#   <ANSTE::Exceptions::InvalidType> - throw if argument has wrong type
#
sub setPackages # (packages)
{
	my ($self, $packages) = @_;

    defined $packages or
        throw ANSTE::Exceptions::MissingArgument('packages');

    if (not $packages->isa('ANSTE::Scenario::Packages')) {
        throw ANSTE::Exceptions::InvalidType('packages',
                                             'ANSTE::Scenario::Packages');
    }

	$self->{packages} = $packages;
}

# Method: files
#
#   Gets the object with the information of files to be transferred.
#
# Returns:
#
#   ref - <ANSTE::Scenario::Files> object.
#
sub files # returns Files object
{
	my ($self) = @_;

	return $self->{files};
}

# Method: setFiles
#
#   Sets the object with the information of files to be transferred.
#
# Parameters:
#
#   packages - <ANSTE::Scenario::Files> object.
#
# Exceptions:
#
#   <ANSTE::Exceptions::MissingArgument> - throw if argument is not present
#   <ANSTE::Exceptions::InvalidType> - throw if argument has wrong type
#
sub setFiles # (files)
{
    my ($self, $files) = @_;

    defined $files or
        throw ANSTE::Exceptions::MissingArgument('files');

    if (not $files->isa('ANSTE::Scenario::Files')) {
        throw ANSTE::Exceptions::InvalidType('files',
                                             'ANSTE::Scenario::Files');
    }

    $self->{files} = $files;
}

# Method: preScripts
#
#   Gets the list of scripts that have to be executed before the setup.
#
# Returns:
#
#   ref - reference to the list of script names
#
sub preScripts # returns list
{
    my ($self) = @_;

    return $self->{'pre-scripts'};
}

# Method: postScripts
#
#   Gets the list of scripts that have to be executed after the setup.
#
# Returns:
#
#   ref - reference to the list of script names
#
sub postScripts # returns list
{
    my ($self) = @_;

    return $self->{'post-scripts'};
}

# Method: precondition
#
#   Gets if this test has passed the required precondition
#
# Returns:
#
#   boolean - true if passed, false if not
#
sub precondition # returns boolean
{
    my ($self) = @_;

    return $self->{precondition};
}

# Method: setPrecondition
#
#   Sets this test passes the required precondition
#
# Parameters:
#
#   ok - boolean that indicates precondition passe
#
sub setPrecondition
{
    my ($self, $ok) = @_;

    $self->{precondition} = $ok;
}

# Method: scenario
#
#   Gets the object with the scenario configuration for the host.
#
# Returns:
#
#   ref - <ANSTE::Scenario::Scenario> object.
#
sub scenario # returns Scenario object
{
	my ($self) = @_;

	return $self->{scenario};
}

# Method: setScenario
#
#   Sets the object with the scenario configuration for the host.
#
# Parameters:
#
#   scenario - <ANSTE::Scenario::Scenario> object.
#
# Exceptions:
#
#   <ANSTE::Exceptions::MissingArgument> - throw if argument is not present
#   <ANSTE::Exceptions::InvalidType> - throw if argument has wrong type
#
sub setScenario # (scenario)
{
	my ($self, $scenario) = @_;

    defined $scenario or
        throw ANSTE::Exceptions::MissingArgument('scenario');

    if (not $scenario->isa('ANSTE::Scenario::Scenario')) {
        throw ANSTE::Exceptions::InvalidType('scenario',
                                             'ANSTE::Scenario::Scenario');
    }

	$self->{scenario} = $scenario;
}

# Method: load
#
#   Loads the information contained in the given XML node representing
#   the host configuration into this object.
#
# Parameters:
#
#   node - <XML::DOM::Element> object containing the test data.
#
# Exceptions:
#
#   <ANSTE::Exceptions::MissingArgument> - throw if parameter is not present
#   <ANSTE::Exceptions::InvalidType> - throw if parameter has wrong type
#
sub load # (node)
{
	my ($self, $node) = @_;

    defined $node or
        throw ANSTE::Exceptions::MissingArgument('node');

    if (not $node->isa('XML::DOM::Element')) {
        throw ANSTE::Exceptions::InvalidType('node',
                                             'XML::DOM::Element');
    }

	my $nameNode = $node->getElementsByTagName('name', 0)->item(0);
	my $name = $nameNode->getFirstChild()->getNodeValue();
	$self->setName($name);

	my $descNode = $node->getElementsByTagName('desc', 0)->item(0);
	my $desc = $descNode->getFirstChild()->getNodeValue();
	$self->setDesc($desc);

    my $typeNode = $node->getAttribute('type');
    if ($typeNode) {
        my $type = $typeNode->getFirstChild()->getNodeValue();
        if ($type eq any ('router', 'pppoe-router', 'dhcp-router')) {
            $self->{type} = $type;
        } else {
            my $error = "Type $type not supported in host $name";
            throw ANSTE::Exceptions::Error($error);
        }
    }

	my $memoryNode = $node->getElementsByTagName('memory', 0)->item(0);
    if ($memoryNode) {
        my $memory = $memoryNode->getFirstChild()->getNodeValue();
	    $self->setMemory($memory);
    }

	my $baseimageNode = $node->getElementsByTagName('baseimage', 0)->item(0);
	my $baseimage = $baseimageNode->getFirstChild()->getNodeValue();
	$self->baseImage()->loadFromFile("$baseimage.xml");

	my $networkNode = $node->getElementsByTagName('network', 0)->item(0);
	if($networkNode){
		$self->network()->load($networkNode);
	}

	my $packagesNode = $node->getElementsByTagName('packages', 0)->item(0);
	if($packagesNode){
		$self->packages()->load($packagesNode);
	}

	my $filesNode = $node->getElementsByTagName('files', 0)->item(0);
	if($filesNode){
		$self->files()->load($filesNode);
	}

	my $preNode = $node->getElementsByTagName('pre-install', 0)->item(0);
	if($preNode){
        $self->_addScripts('pre-scripts', $preNode);
	}

	my $postNode = $node->getElementsByTagName('post-install', 0)->item(0);
	if($postNode){
        $self->_addScripts('post-scripts', $postNode);
	}

    # Check if all preconditions are satisfied
    my $configVars = ANSTE::Config->instance()->variables();
	my $preconditionNodes = $node->getElementsByTagName('precondition', 0);
    for (my $i = 0; $i < $preconditionNodes->getLength(); $i++) {
        my $var = $preconditionNodes->item($i)->getAttribute('var');
        my $expectedValue = $preconditionNodes->item($i)->getAttribute('eq');
        my $value = $configVars->{$var};
        unless (defined $value) {
            $value = 0;
        }
        if ($value ne $expectedValue) {
            $self->setPrecondition(0);
            last;
        }
    }
}

sub _addScripts # (list, node)
{
    my ($self, $list, $node) = @_;

	foreach my $scriptNode ($node->getElementsByTagName('script', 0)) {
        my $script = $scriptNode->getFirstChild()->getNodeValue();
        push(@{$self->{$list}}, $script);
    }
}


1;
