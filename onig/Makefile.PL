system "./configure --prefix=/tmp" and die "./configure failed: $?\n";

die "No Makefile created\n" unless -f 'Makefile';

# Really crufty: patch up Makefile so that make test doesn't barf.

open my $mf, '>>', 'Makefile' or die "Can't append to Makefile: $!\n";
print $mf "\ntest ::\n";
print $mf "\t\@echo No tests defined for Oniguruma\n";
close $mf;
