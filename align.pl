#!/usr/bin/perl
use strict;
use Carp;
use Data::Dumper;
my $gSoxPath        = "/Users/pete/OctaConvert/sox-14.4.2/sox";
my $gVerbose        = 0;
my $gTempTemplate   = "/tmp/align.$$";
my $gNextTempfile   = 0;

my %gTrackMap = (
    "MASTER"     => {sym=>"ms"},
    "TRACK1"     => {sym=>"OT"},
    "TRACK2"     => {sym=>"OT"},
    "TRACK3"     => {sym=>"OT"},
    "TRACK4"     => {sym=>"OT"},
    "TRACK5"     => {sym=>"OT"},
    "TRACK6"     => {sym=>"OT"},
    "TRACK7"     => {sym=>"OT"},
    "TRACK8"     => {sym=>"OT"},
    "TRACK9"     => {sym=>"OT"},
    "TRACK10"    => {sym=>"OT"},
    "TRACK11"    => {sym=>"DN"},
    "TRACK12"    => {sym=>"DN"},
    "TRACK13"    => {sym=>"OT"},
    "TRACK14"    => {sym=>"OT"},
    "TRACK15"    => {sym=>"OT"},
    "TRACK16"    => {sym=>"OT"},
    "TRACK17_18" => {sym=>"OT"},
    "TRACK19_20" => {sym=>"OT"},
);



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
    return "$gTempTemplate.$i.wav";
}

sub soxSilence {
    my ($inputFile, $outputFile) = @_;
    run("$gSoxPath $inputFile $outputFile silence 1 0.01 0.01");
}

sub soxTrim {
   my ($inputFile, $outputFile, $startSeconds, $lengthSeconds) = @_;
   run("$gSoxPath $inputFile $outputFile trim $startSeconds $lengthSeconds");
}

sub soxStat {
    my ($inputFile) = @_;
    my $tfile = tempFile();
    my @lines = backtick("$gSoxPath $inputFile $tfile stat 2>&1");
    chomp(@lines);
    my $grabField = sub {
        my (undef, $value) = split ":", $_[0];
        $value =~ s/\s//g;
        return $value;
    };

    my %stat;
    for my $line (@lines) {
        if ($line =~ /Length/) {
    	    $stat{length} = $grabField->($line);
    	} elsif ($line =~ /Maximum amplitude/) {
            $stat{maxAmp} = $grabField->($line);
        } elsif ($line =~ /Minimum amplitude/) {
            $stat{minAmp} = $grabField->($line);
        }
    }
    run("rm -f $tfile");
    die "Failed to find Length in $inputFile from soxStat" unless defined($stat{length});
    return \%stat;
}

sub legitProjectName {
    my ($projectPath) = @_;
    my @path = split "/", $projectPath;
    my $projectName   = $path[-1];
    my ($date, $time) = split "_", $projectName;
    return 0 unless defined($time); 
    return 0 unless $date =~ /^\d\d\d\d\d\d$/;
    return 0 unless $time =~ /^\d\d\d\d\d\d$/;
    return 1;
}

## listProjects returns all the project directories found in the input directory
sub listProjects {
   my ($projectDirDir) = @_;
   my @files = backtick("ls $projectDirDir/*");
   my @projects;
   for my $file (@files) {
	push @projects, $file if legitProjectName($file);
   }
   return @projects;
}


## listTracks picks up all the tracks in a project directory
sub listTracks {
    my ($projectDir) = @_;
    my @lines = backtick("ls $projectDir/*");
    chomp(@lines);
    my @tracks;
    for my $file (@lines) {
        next unless $file =~ /TRACK[0-9]{1,2}\.WAV$/i || $file =~ /MASTER.WAV$/i;
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
    my @returnTracks;
    for my $track (@tracks) {
        my $originalStat = soxStat($track);
        soxSilence($track, $resultFile);
        my $silencedStat = soxStat($resultFile);
        my $len          = $originalStat->{length} - $silencedStat->{length};
        if ($minSilenceLen < 0 || $len < $minSilenceLen) {
	        $minSilenceLen = $len;
	    }
        run("rm -f $resultFile");
    }
    return $minSilenceLen; 
}

sub trackFile2Symbol {
    my ($trackFile) = @_;
    my @path = split "/", $trackFile;
    my $track = $path[-1];
    $track =~ s/\.wav$//i;
    my $h = $gTrackMap{$track};
    return "un" unless defined($h);
    return $h->{sym};
}

sub computeNextIndexs {
    my ($outputDir) = @_;
    my @files = backtick("ls $outputDir/* 2> /dev/null", noexit=>1);
    chomp(@files);
    my %next;
    for my $file (@files) {
        next unless $file =~ /\.wav$/i;
        $file =~ s{[^/]*/}{};
        my ($symbol, $count) = split '\.', $file;
        next unless defined($count) && $count =~ /^\d+$/;
        if (!defined($next{$symbol}) || $count > $next{$symbol}) {
            $next{$symbol} = $count;
        } 
    }
    return %next;
}

sub main {
    my ($projectInputDir, $outputDir, $bpm, $loopBars) = @ARGV;
    confess "Failed to specify project dir" unless @ARGV >= 3;
    confess "Bad bpm $bpm" if $bpm < 0 || $bpm > 200;
    confess "Bad loopBars $loopBars" if $loopBars < 0 || $loopBars > 128;
    confess "Can't find projectInputDir $projectInputDir" unless -d $projectInputDir;
    confess "Can't find outputDir $outputDir" unless -d $outputDir;
    $projectInputDir =~ s[/$][];
    $outputDir       =~ s[/$][];

    my @tracks            = listTracks($projectInputDir);
    my %nexts             = computeNextIndexs($outputDir);
    my $trimLengthSeconds = findSilentTrimLength($projectInputDir);
    my $loopLengthSeconds = (60.0/$bpm) * 4 * $loopBars;    

    for my $track (@tracks) {
        my $symbol = trackFile2Symbol($track);
        my $cnt    = 0;
        if (defined($nexts{$symbol})) {
            $cnt = $nexts{$symbol};
            $nexts{$symbol}++;
        } else {
            $nexts{$symbol} = $cnt+1;
        }
        my $newName = "$outputDir/$symbol.$cnt.wav";

        print "$track --> $newName ($trimLengthSeconds) [$loopLengthSeconds]\n";
        soxTrim($track, $newName, $trimLengthSeconds, $loopLengthSeconds);
    }
}

main();

