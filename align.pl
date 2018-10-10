#!/usr/bin/perl
use strict;
use Carp;
my $gSoxPath   = "./sox-14.4.2/sox";
my $gVerbose   = 0;
my $gTempTemplate = "/tmp/align.$$";
my $gNextTempfile = 0;

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

sub tempFile {
    my $i = $gNextTempfile;
    $gNextTempfile++;
    return "$gNextTempfile.$i";
}

sub soxSilence {
    my ($inputFile, $outputFile) = @_;
    run("$gSoxPath $inputFile $outputFile silence 1 0 0.000001");
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
   my ($projectDir) = @_;
}


## listTracks picks up all the tracks in a project directory
sub listTracks {
    my ($projectDir) = @_;
    my @lines = backtick("ls $projectDir/*.wav");
    chomp(@lines);
    my @tracks;
    for my $file (@lines) {
        next unless /TRACK[0-9]{1,2}\.WAV$/i || /MASTER.WAV$/i;
	push @tracks, $file;
    }
    return @tracks;
}

## findSilentTrimLength scans all of the tracks in a project directory and computes the start-point for the loops.
## The start point is the longest length (considering all tracks and the master track) that captures ONLY silence 
## for all the tracks.
sub findSilentTrimLength {
    my ($projectDir)  = @_;
    my $resultFile    = tempFile();
    my @tracks        = listTracks($projectDir);
    confess "No tracks found in $projectDir" unless @tracks;
    my $minSilenceLen = -1;
    for my $track (@tracks) {
    	soxSilence($track, $resultFile);
        my $originalStat = soxStat($track);
        my $silencedStat = soxStat($track);
        my $len          = $originalStat->{length} - $silencedStat->{length};
        if ($minSilenceLen < 0 || $len < $minSilenceLen) {
	   $minSilenceLen = $len;
	}
        run("rm -f $resultFile");
    }
    return $minSilenceLen; 
}





