use 5.008;
use warnings;
package Devel::DidYouMean;

use vars qw($AUTOLOAD);
use Text::Levenshtein;
use Perl::Builtins;
use Carp 'croak';
no warnings 'once';
no strict qw/refs subs/;

# ABSTRACT: Intercepts failed function and method calls, suggesting the nearest matching alternative.

=head2 SYNOPSIS

    #!/usr/bin/env perl

    # somescript.pl
    use Data::Dumper;
    use Devel::DidYouMean;

    print Dumpr($data); # wrong function name

*Run the code*

    $ somescript.pl
    Undefined subroutine 'Dumpr' not found in main. Did you mean Dumper? at somescript.pl line 7.

Or as a one liner:

    $ perl -MData::Dumper -MDevel::DidYouMean -e 'print Dumpr($data)'
    Undefined subroutine 'Dumpr' not found in main. Did you mean Dumper? at -e line 1.

Or trap the error and extract the matching subs

    use Devel::DidYouMean;
    use Try::Tiny;

    try
    {
        sprintX("", $text); # boom
    }
    catch
    {
        my $error_msg = $_;
        my @closest_matching_subs = @$Devel::DidYouMean::DYM_MATCHING_SUBS;

        # do something cool here
    }

=head2 DESCRIPTION

L<Devel::DidYouMean> intercepts failed function and method calls, suggesting the nearest matching available subroutines in the context in which the erroneous function call was made.

=head2 WARNING

This library is experimental, on load it exports an AUTOLOAD subroutine to every namespace in the symbol table. In version 0.03 and higher, this library must be loaded using C<use> and not C<require>. In version 0.04 and higher it will not overwrite an existing AUTOLOAD in a namespace.

=cut

=head2 THANKS

This module was inspired by Yuki Nishijima's Ruby gem L<did_you_mean|https://github.com/yuki24/did_you_mean>.

Chapter 9 "Dynamic Subroutines" in L<Mastering Perl|http://shop.oreilly.com/product/0636920012702.do> second edition by brian d foy was a vital reference for understanding Perl's symbol tables.

=cut

=head2 SEE ALSO

L<Symbol::Approx::Sub> is a similar module that catches invalid subroutine names and then executes the nearest matching subroutine it can find. It does not export AUTOLOAD to all namespaces in the symbol table.

=cut

our $DYM_MATCHING_SUBS = [];

CHECK {

    # add autoload to main
    *{ main::AUTOLOAD } = Devel::DidYouMean::AUTOLOAD;

    # add to every other module in memory
    for (keys %INC)
    {
        my $module = $_;
        $module =~ s/\//::/g;
        $module = substr($module, 0, -3);
        $module .= '::AUTOLOAD';
        
        # skip if the package already has an autoload
        next if defined *{ $module };
        
        *{ $module } = Devel::DidYouMean::AUTOLOAD;
    }
}

sub AUTOLOAD
{
    my @sub_path = split /::/, $AUTOLOAD;
    my $sub = pop @sub_path;

    # ignore these calls
    return if grep /$sub/, qw/AUTOLOAD BEGIN CHECK INIT DESTROY END/;

    my $package = join '::', @sub_path;
    my $package_namespace = $package . '::';

    my %valid_subs = ();

    for (keys %$package_namespace)
    {
        my $absolute_name = $package_namespace . $_;
        if (defined &{$absolute_name})
        {
            $valid_subs{$_} = Text::Levenshtein::fastdistance($sub, $_);
        }
    }

    # if package is main, add in builtin functions
    if ($package eq 'main')
    {
        for (Perl::Builtins::list)
        {
            $valid_subs{$_} = Text::Levenshtein::fastdistance($sub, $_);
        }
    }

    $DYM_MATCHING_SUBS = [];
    my $match_score;

    # return similarly named functions
    for (sort { $valid_subs{$a} <=> $valid_subs{$b} } keys %valid_subs)
    {
        next if $_ eq 'AUTOLOAD';
        $match_score = $valid_subs{$_} unless $match_score;

        if ($match_score < $valid_subs{$_})
        {
            croak "Undefined subroutine '$sub' not found in $package. Did you mean " 
                . join(', ', @$DYM_MATCHING_SUBS) . '?';
        }
        push @$DYM_MATCHING_SUBS, $_;
    }
}

1;
