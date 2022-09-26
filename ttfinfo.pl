#! /usr/bin/perl

=head1 NAME

ttfinfo - report information about fonts (.ttf, .ttc, .otf ...)

=head1 SYNOPSIS

B<ttfinfo> [B<-iap> B<--csv>] I<FILE...>

=cut

use strict;
use warnings;
use feature qw(say);

use Data::Dumper;
use Getopt::Long;
use Image::ExifTool qw(:Public);
use Pod::Usage;
use Text::CSV_XS;

my %data;
my %keys;
my %opt;
my $query = "info";


sub heredoc {
    # my $text = heredoc(<<"TARGET");
    #   or
    # print heredoc(<<"TARGET");
    local $_ = shift;
    my ($white, $leader);  # common whitespace and common leading string
    if (/^\s*(?:([^\w\s]+)(\s*).*\n)(?:\s*\1\2?.*\n)+$/) {
        ($white, $leader) = ($2, quotemeta($1));
    } else {
        ($white, $leader) = (/^(\s+)/, '');
    }
    s/^\s*?$leader(?:$white)?//gm;
    return $_;
}

=head1 OPTIONS

=over 4

=item B<-i>, B<--info>

Print all information about font.

=item B<-n>, B<--name>

Print each font's name.

=item B<-a>, B<--family>

Print each font's family name.

=item B<-p>, B<--postscript-name>

Print each font's PostScript name.

=item B<--csv>

Print all information about font, CSV format

=item B<-A>, B<--firstfamily>

UNDOCUMENTED FEATURE.  use the source, luke.

=item B<-N>, B<--firstname>

UNDOCUMENTED FEATURE.  use the source, luke.

=back

=cut

Getopt::Long::Configure(qw(no_ignore_case));
GetOptions(\%opt,
           'name|n'         => sub { $query = "name"; },
           'family|a'       => sub { $query = "family"; },
           'postscript|postscript-name|p' => sub { $query = "postscript"; },
           'info|i'         => sub { $query = "info"; },
           'csv'            => sub { $query = "csv"; },
           'html'           => sub { $query = "html"; },
           'firstfamily|A'  => sub { $query = "firstfamily"; },
           'firstname|N'    => sub { $query = "firstname"; },
           'help|h'         => sub { pod2usage(-verbose => 1); },
           'man'            => sub { pod2usage(-verbose => 2); },
    ) or pod2usage(-verbose => 1);

#die Dumper $query;

for my $filename (@ARGV) {
    unless ( -f $filename ) {
        warn "$filename: $!\n";
        next;
    }

    my $font = new Image::ExifTool;
    $font->ImageInfo($filename, "FONT:*");

    for my $tag (sort $font->GetFoundTags) {
        $keys{$tag}++;
        $data{$filename}{$tag} = $font->GetValue($tag);
    }
}

for($query) {
    /^info$/ && do {
        for my $filename (sort keys %data) {
            my $longestkeylength = (reverse sort { $a <=> $b } map { length($_) } keys %{$data{$filename}} )[0];
            print "======== $filename\n";
            for my $key (sort keys %keys) {
                if ($data{$filename}{$key}) {
                    my $value = $data{$filename}{$key};
                    $value =~ s:\x0d\x0a:\n:g;
                    for my $line (split /\n/,$value) {
                        printf("%-${longestkeylength}s : $line\n", $key);
                    }
                }
            }
            print "\n";
        }
    };

    /^name$/ && do {
        for my $filename (sort keys %data) {
            my %name = ();
            for my $key (sort keys %keys) {
                if ($key =~ /^FontName/ and $data{$filename}{$key}) {
                    $name{$data{$filename}{$key}}++;
                }
            }
            print("$filename:".join(",",sort keys %name)."\n");
        }
    };

    /^family$/ && do {
        for my $filename (sort keys %data) {
            my %family = ();
            for my $key (sort keys %keys) {
                if ($key =~ /^FontFamily/ and $data{$filename}{$key}) {
                    $family{$data{$filename}{$key}}++;
                }
            }
            print("$filename:".join(",",sort keys %family)."\n");
        }
    };

    /^firstname$/ && do {
        for my $filename (sort keys %data) {
            my %name = ();
            for my $key (sort keys %keys) {
                if ($key =~ /^FontName/ and $data{$filename}{$key}) {
                    $name{$data{$filename}{$key}}++;
                }
            }
            my @names = sort keys %name;
            print("$names[0]\n");
        }
    };

    /^firstfamily$/ && do {
        for my $filename (sort keys %data) {
            my %family = ();
            for my $key (sort keys %keys) {
                if ($key =~ /^FontFamily/ and $data{$filename}{$key}) {
                    $family{$data{$filename}{$key}}++;
                }
            }
            my @families = sort keys %family;
            print("$families[0]\n");
        }
    };

    /^postscript$/ && do {
        for my $filename (sort keys %data) {
            my %psname = ();
            for my $key (sort keys %keys) {
                if ($key =~ /^PostScriptFontName/ and $data{$filename}{$key}) {
                    $psname{$data{$filename}{$key}}++;
                }
            }
            print("$filename:".join(",",sort keys %psname)."\n");
        }
    };

    /^csv$/ && do {
        my $csv = Text::CSV_XS->new({binary => 1, eol => $/ });
        my @cols = sort keys %keys;
        # header line
        my $status = $csv->combine("Filename",@cols);
        print $csv->string();
        # each package
        for my $filename (sort keys %data) {
            my @line = ($filename);
            for my $key (@cols) {
                push(@line, ($data{$filename}{$key})?($data{$filename}{$key}):"");
            }
            $status = $csv->combine(@line);
            print $csv->string();
        }
    };

    /^html$/ && do {
        print heredoc(<<"##__HTML__##");
# <html>
# <head><title>TTF INFO</title></head>
# <body>
# <h1>TTF INFO</h1>
##__HTML__##
        for my $filename (sort keys %data) {
            my $longestkeylength = (reverse sort { $a <=> $b } map { length($_) } keys %{$data{$filename}} )[0];
            print "<h2>$filename</h2>\n";
            print "<h3>$data{$filename}{FontFamily}</h3>\n";
            print "<pre>\n";
            for my $key (sort keys %keys) {
                if ($data{$filename}{$key}) {
                    my $value = $data{$filename}{$key};
                    $value =~ s:\x0d\x0a:\n:g;
                    for my $line (split /\n/,$value) {
                        printf(qq(%-${longestkeylength}s : <span style="font-family:$data{$filename}{FontFamily}">$line</span>\n), $key);
                    }
                }
            }
            print "</pre>\n";
    }
    print heredoc(<<"##__HTML__##");
# </body>
# </html>
##__HTML__##
    };
}
