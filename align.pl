#!/usr/bin/perl
use strict;
use Carp;
my $gSoxPath   = "./sox-14.4.2/sox";
my $gVerbose   = 0;
my $gTempTemplate = "/tmp/align.$$";
my $gNextTempfile = 0;

sub tempFile {
    my $i = $gNextTempfile;
    $gNextTempfile++;
    return "$gNextTempfile.$i";
}

sub soxSilence {
    my ($inputFile, $outputFile) = @_;
# ../../sox-14.4.2/sox TRACK17_18.WAV x.wav silence 1 0 0.000001

}

sub soxTrim {
   my ($inputFile, $outputFile, $startSeconds, $lengthSeconds) = @_;
   run("$gSoxPath $inputFile $outputFile trim $startSeconds $lengthSeconds");
}

sub soxStat {
    my ($inputFile) = @_;
    my $tfile = tempFile();
    my @lines = backtick("$gSoxPath $inputFile $tfile stat");
    chomp(@lines);
    my %stat;
    for my $line (@lines) {
        if ($line =~ /Length/) {
	    my (undef, $length) = split ":", $line;
	    $length =~ s/\s//g;
	    $stat{length} = $length;
	}
    }
    die "Failed to find Length in $inputFile from soxStat" unless defined($stat{length});
    return \%stat;
}

sub parseProjectName {
    my ($projectName) = @_;

}

## listProjects returns all the project directories found in the input directory
sub listProjects {
}


## listTracks picks up all the tracks in a project directory
sub listTracks {

}

## findSilentTrimLength scans all of the tracks in a project directory and computes the start-point for the loops.
## The start point is the longest length (considering all tracks and the master track) that captures ONLY silence 
## for all the tracks.
sub findSilentTrimLength {
    my ($projectDir) = @_;
    my $tfile = tempFile();
     
}

