use strict;
use warnings;
package Devel::DidYouMean;

use feature 'say';
use vars qw($AUTOLOAD);
use Text::Levenshtein;
use Carp 'croak';
no warnings 'once';
no strict qw/refs subs/;

# ABSTRACT: Intercepts failed function and method calls, suggesting the nearest matching alternative.

=head2 SYNOPSIS
    #!/usr/bin/env perl
    # somescript.pl
    use Data::Dumper;
    require Devel::DidYouMean;

    print Dumpr($data); # wrong function name
    ...

*Run the code*

    $ somescript.pl
    Undefined subroutine 'Dumpr' not found in main. Did you mean Dumper? at somescript.pl line 6.

Or add as a one liner:

    $ perl -Ilib -mData::Dumper -MDevel::DidYouMean -e 'Data::Dumper::Dumpr($data)'
    Undefined subroutine 'Dumpr' not found in Data::Dumper. Did you mean Dumper? at -e line 1.

=head2 DESCRIPTION

L<Devel::DidYouMean> intercepts failed function and method calls, suggesting the nearest matching available function or method in the context in which the erroneous function call was made. This library is experimental, on load it exports an AUTOLOAD subroutine to every namespace in the symbol table. Therefore it should be loaded last in your program, preferably using C<require>.

=cut

=head2 THANKS

This module was inspired by Yuki Nishijima's Ruby gem L<did_you_mean|https://github.com/yuki24/did_you_mean>.

=cut

our $DYM_MATCHING_SUB = undef;

# add main
*{ main::AUTOLOAD } = Devel::DidYouMean::AUTOLOAD;

# add to every other module !
for (keys %INC)
{
    my $module = $_ =~ s/\//::/gr;
    $module = substr($module, 0, -3);

    next if $module eq __PACKAGE__;

    $module .= '::AUTOLOAD';
    *{ $module } = Devel::DidYouMean::AUTOLOAD;
}

my @functions = qw/AUTOLOAD
abs
accept
alarm
and
atan2
BEGIN
bind
binmode
bless
CHECK
caller
chdir
chmod
chomp
chop
chown
chr
chroot
close
closedir
cmp
connect
continue
crypt
DESTROY
__DATA__
dbmclose
dbmopen
default
defined
delete
die
do
dump
END
__END__
each
else
elseif
elsif
endgrent
endhostent
endnetent
endprotoent
endpwent
endservent
eof
eq
eval
evalbytes
exec
exists
exit
exp
__FILE__
fc
fcntl
fileno
flock
for
foreach
fork
format
formline
ge
getc
getgrent
getgrnam
gethostbyaddr
gethostbyname
gethostent
getnetbyaddr
getnetbyname
getnetent
getpgrp
getppid
getpriority
getprotobyname
getprotobynumber
getprotoent
getpwent
getpwnam
getpwuid
getservbyname
getservbyport
getservent
getsockopt
given
glob
gmtime
goto
grep
gt
hex
INIT
if
import
index
int
ioctl
join
keys
kill
__LINE__
last
lc
lcfirst
le
length
link
listen
localtime
lock
log
lstat
lt
m
map
mkdir
msgctl
msgget
msgrcv
msgsnd
my
ne
next
no
not
oct
open
opendir
or
ord
our
__PACKAGE__
pack
package
pipe
pop
pos
print
printf
prototype
push
q
qq
qr
qw
qx
rand
readdir
readline
readlink
readpipe
recv
redo
ref
rename
require
reset
return
reverse
rewinddir
rindex
rmdir
__SUB__
s
say
scalar
seek
seekdir
semctl
semget
semop
send
setgrent
sethostent
setnetent
setpgrp
setpriority
setprotoent
setpwent
setservent
setsockopt
shift
shmctl
shmget
shmread
sin
sleep
socket
socketpair
sort
split
sprintf
srand
stat
state
study
sub
substr
symlink
syscall
sysopen
sysread
sysseek
system
tell
telldir
tie
time
times
tr
truncate
UNITCHECK
uc
ucfirst
umask
undef
unless
unlink
unpack
unshift
untie
until
use
utime
values
vec
wait
waitpid
wantarray
warn
when
while
write
-X
x
xor
y/;

sub AUTOLOAD {
    require Text::Levenshtein;

    my @sub_path = split /::/, $AUTOLOAD;
    my $sub = pop @sub_path;
    return if $sub eq 'DESTROY';

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
        for (@functions)
        {
            $valid_subs{$_} = Text::Levenshtein::fastdistance($sub, $_);
        }
    }

    for (sort { $valid_subs{$a} <=> $valid_subs{$b} } keys %valid_subs)
    {
        next if $_ eq 'AUTOLOAD';
        $DYM_MATCHING_SUB = $_;
        croak "Undefined subroutine '$sub' not found in $package. Did you mean $_?";
    }
}

1;
