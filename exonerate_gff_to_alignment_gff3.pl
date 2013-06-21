#!/usr/bin/env perl

use strict;
use warnings;


=EXONERATE_COMMAND

exonerate --model p2g --showvulgar no --showalignment no --showquerygff no --showtargetgff yes --percent 80 --ryo "AveragePercentIdentity: %pi\n" protein_db.pep target_genome.fasta

=cut


my $usage = "\n\nusage: $0 exonerate.gff\n\n";

my $alignment_gff = $ARGV[0] or die $usage;


my $MATCH_COUNTER = 0;

main: {


    my $contig = "";
    my $target = "";
    my $orient = "";
    my @segments = ();
    my $per_id = "";
    my @rel_coords;

    open (my $fh, $alignment_gff) or die "Error, cannot open file $alignment_gff";
    ## get to first entry
    while (<$fh>) {
        if (/START OF GFF DUMP/) {
            last;
        }
    }
    
    while (<$fh>) {
        if (/^\#/) { next; }
        if (/^\-\-/) { next; }
        chomp;
        if (/AveragePercentIdentity: (\S+)/) {
            $per_id = $1;
            &process_gff_entry($contig, $target, $orient, \@segments, $per_id, \@rel_coords);
            # re-init 
            $contig = "";
            $target = "";
            $orient = "";
            @segments = ();
            $per_id = "";
            @rel_coords = ();
        }
        else {
            my @x = split(/\t/);
            unless (scalar(@x) >= 8) {
                die "Error, line has unexpected format: $_";
            }
            my $feat_type = $x[2];
            if ($feat_type eq 'gene') {
                $x[8] =~ /sequence (\S+)/ or die "Error, cannot parse target from $_";
                $target = $1;
            }
            elsif ($feat_type eq 'exon') {
                $contig = $x[0];
                $orient = $x[6];
                my ($lend, $rend) = sort {$a<=>$b} ($x[3], $x[4]);
                push (@segments, [$lend, $rend]);
            }
            
            elsif ($feat_type eq 'similarity') {
                while ($x[8] =~ /Align \d+ (\d+) (\d+)/g) {
                    my ($pos, $len) = ($1, $2);
                    push (@rel_coords, [$pos, $len]);
                }
            }
                        
        }
    }
    close $fh;


    exit(0);
}


####
sub process_gff_entry {
    my ($contig, $target, $orient, $segments_aref, $per_id, $rel_coords_aref) = @_;

    $MATCH_COUNTER++;

    foreach my $segment (@$segments_aref) {
        my ($lend, $rend) = @$segment;
        
        my $rel_info = shift @$rel_coords_aref;
        my ($rel_pos, $rel_len) = @$rel_info;
        my $rel_lend = $rel_pos;
        my $rel_rend = $rel_pos + $rel_len/3;

        print join("\t", $contig, "exonerate", "nucleotide_to_protein_match", 
                   $lend, $rend, $per_id, $orient,
                   ".", "ID=match.$$.$MATCH_COUNTER;Target=$target $rel_lend $rel_rend") . "\n";
    }
    print "\n"; # add spacer between alignments.

    return;
}


                       
            
            
            
