#!/usr/bin/perl

=pod

=head1 NAME

invitel-outages-reporter - connects to the Invitel maintenance page and search for outages for the next week, results will be displayed. The cities and streets are hard coded.

=head1 SYNOPSIS

B<invitel-outages-reporter>

=head1 AUTHOR

Kiss Zoltan Laszlo, email: laszlo.zoltan.kiss@gmail.com

=head1 HISTORY

Created: 2018.03.08

Last modification: 2018.03.08

=cut

use strict;
use warnings;
use Data::Dumper;

sub mail {
  my $address = shift;
  my $subject = shift;
  $subject =~ s/ /\\ /g;
  my $message = '\''; # the message should start/end with ', otherwise
                    # only one line messages can be sent.
  $message .= shift;
  $message .= '\'';
  `ssh kzl\@192.168.1.1 "echo $message | mail -s $subject $address"`;
}

sub invitel {

  my $cities = shift;
  my $streets = shift;

  sub convert_date {
    my $date = shift;
    my $date_converted;
    my %mon2num = qw(
      Jan 01  Feb 02  Mar 03  Apr 04  May 05  Jun 06
      Jul 07  Aug 08  Sep 09  Oct 10 Nov 11 Dec 12
      );
    if ($date =~ /\S+ (\S+)\s+(\d+) .+ (\d+)/) {
      my $day; if ($2 < 10) { $day = '0' . $2 } else { $day = $2 }
      $date_converted = $3 . '.+' . $mon2num { $1 } . '.+' . $day ;
    }
    return $date_converted;
  }

  my $start_date = localtime;
  $start_date = convert_date($start_date);

  my $future = time + 604800;
  my $finish_date = localtime($future);
  $finish_date = convert_date($finish_date);

  my $link = 'https://www.invitel.hu/ugyfelszolgalat/karbantartasi-informaciok?type=minden&start_date=';
  $link .= $start_date . '&finish_date=';
  $link .= $finish_date . '&settlement=minden';

  `wget -q \'$link\' -O /media/ramdisk0/invitel`;

  my @outages_container;
  open ( my $invitel_fh , "<", "/media/ramdisk0/invitel") or die "Could not open file 'invitel' $!";
  while (my $row = <$invitel_fh>) {
    if ( $row =~ /\t{8}<p><b>(.+)<\/b><\/p>/ ) {
      my $value = $1;
      $value =~ s/^\s+|\s+$//g;
      push @outages_container, $value;
    } elsif ( $row =~ /\t{8}<p>(.+)<\/p>/ ) {
      my $value = $1;
      $value =~ s/^\s+|\s+$//g;
      push @outages_container, $value;
    }
  }
  close $invitel_fh;


  my @maintenances_container;
  my $pointer = -1;
  for (my $i = 0; $i < scalar @outages_container; $i=$i+2){
    if ($outages_container[$i] =~ /Karbantartás típusa/) { $pointer++ }
    ${$maintenances_container[$pointer]}->{$outages_container[$i]} = $outages_container[$i+1];

  }

  `rm /media/ramdisk0/invitel`;

  if ($cities && $streets) {
    my @choosen_maintenances;
    for (my $i = 0; $i < scalar @$cities; $i++) {
      foreach (@maintenances_container) {
        if ( ${$_}->{'Érintett terület'} =~ $streets->[$i] ) {
          if ( (${$_}->{'Település'}) =~ ($cities->[$i]) ) { push @choosen_maintenances, $_ } ;
        }
      }
    }
    return \@choosen_maintenances;
  } else { return \@maintenances_container}

}

my @cities = qw ( Debrecen );
my @streets = qw ( Vágóhíd );
my $outages = invitel (\@cities, \@streets);
my $report;
foreach (@$outages) {
  $report .= 'Karbantartás típusa: ' . ${$_}->{'Karbantartás típusa'} . "\n";
  $report .= 'Szolgáltató: ' . ${$_}->{'Szolgáltató'} . "\n";
  $report .= 'Település: ' . ${$_}->{'Település'} . "\n";
  $report .= 'Érintett terület: ' . ${$_}->{'Érintett terület'} . "\n";
  $report .= 'Dátum: ' . ${$_}->{'Dátum'} . "\n";
  $report .= 'Időszak: ' . ${$_}->{'Időszak'} . "\n";
  $report .= 'Érintett szolgáltatás: ' . ${$_}->{'Érintett szolgáltatás'} . "\n";
}
print $report;
