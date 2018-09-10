#!/usr/bin/perl
use strict;
use Carp;
##NOTE: This program assumes that the input directory is populated with files that are either 
##	(a) 32 bit files that will be conveted, with the output going into output
##  (b) Either a 24bit or 16bit file which will just be copied over to output.

my $gSoxPath   = "./sox-14.4.2/sox";
my $gVerbose   = 1;
my $gInputDir  = "input";
my $gOutputDir = "output";
sub backtick {
    my ($command, %opts) = @_;
    print "$command\n" if $gVerbose;
    my @lines = `$command`;
    if ($?) {
        confess "Failed '$command': $!" unless $opts{noexit};
        return ();
    }
    chomp(@lines);
    return @lines;
}

sub run {
    my ($cmd) = @_;
    print "$cmd\n" if $gVerbose;
    if (system $cmd){
        confess "Failed: '$cmd': $!";
    }
}

## This function only detects 32-bit floating point.
sub needsConverting {
	my ($inputPath) = @_;
	my ($encoding) = grep {/Sample Encoding/} backtick("$gSoxPath --i $inputPath");
	confess "Failed to find bit depth of file $inputPath" unless defined($encoding);
	return $encoding =~ /32-bit Floating Point/;
}

sub convertFromInputToOutput {
	my ($inputDir, $outputDir) = @_;
	my @inPaths = backtick("ls $inputDir/*");
	@inPaths = grep {/\.wav$/} @inPaths;
	my $verbose = $gVerbose ? "-V4" : "";
	my $cmdPre     = "$gSoxPath $verbose";
	for my $inPath (@inPaths) {
		confess "ERROR: Failed to match inPath" unless $inPath =~ m{/([^/]+)$};
		my $inFile  = $1;
		my $outPath = "$outputDir/$inFile";
		if (needsConverting($inPath)) {
			my $cmd = "$cmdPre $inPath -r44.1k -b 24 -e signed-integer $outPath";
			run $cmd;
		}
		else {
			run "cp $inPath $outPath";
		}
	}
}

sub main {
	confess "Failed to find $gInputDir dir" unless -d $gInputDir;
	confess "Failed to find $gOutputDir dir" unless -d $gOutputDir;
	convertFromInputToOutput($gInputDir, $gOutputDir);
}

main();