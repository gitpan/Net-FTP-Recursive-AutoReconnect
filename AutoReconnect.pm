package Net::FTP::Recursive::AutoReconnect;
our $VERSION = '1.0';

#use warnings;
#use strict;
use Net::FTP;
use Cwd 'getcwd';

sub new {
	my $self = {};
	my $class = shift;
	bless $self,$class;

	if (@_ % 2){
		$self->{_peer} = shift;
		$self->{_args} = { @_ };
	}else{
		$self->{_args} = { @_ };
		$self->{_peer} = delete $self->{_args}{Host};
	}
	$self->{_connect_count} = 0;
	$self->reconnect( 0 );
	$self;
}

sub reconnect {
	my $self = shift;
	my $is_reconnect = shift;
	my $connection_type = ($is_reconnect) ? "Reconnecting" : "Connecting";

	warn join(' ',ref($self),$connection_type." to FTP server $self->{_peer}\n") if($ENV{DEBUG} || $self->{_args}{Debug});
	++$self->{_connect_count};
	$self->{ftp} = Net::FTP->new($self->{_peer}, %{$self->{_args}}) or die "Couldn't create new FTP object: $@\n";

	if ($self->{login}){
		$self->{ftp}->login(@{$self->{login}});
	}
	if($self->{authorize}){
		$self->{ftp}->authorize(@{$self->{authorize}});
	}
	if($self->{mode}){
		if ($self->{mode} eq 'ascii'){
			$self->{ftp}->ascii();
		}else{
			$self->{ftp}->binary();
		}
	}
	if($self->{cwd}){
		$self->{ftp}->cwd($self->{cwd});
	}
	if($self->{hash}){
		$self->{ftp}->hash(@{$self->{hash}});
	}
	if($self->{restart}){
		$self->{ftp}->restart(@{$self->{restart}});
	}
	if($self->{alloc}){
		$self->{ftp}->restart(@{$self->{alloc}});
	}
	if($self->{pasv}){
		$self->{ftp}->pasv(@{$self->{pasv}});
	}
	if($self->{port}){
		$self->{ftp}->port(@{$self->{port}});
	}
}

sub _auto_reconnect {
	my $self = shift;
	my($code)=@_;

	my $ret = $code->();
	if(!defined($ret)){
		$self->reconnect( 1 );
		$ret = $code->();
	}
	$ret;
}

sub _after_pcmd {
	my $self = shift;
	my($r) = @_;
	if($r){
		delete $self->{port};
		delete $self->{pasv};
		delete $self->{restart};
		delete $self->{alloc};
	}
	$r;
}

sub disconnect {
	my $self = shift;
	return POSIX::close(fileno($self->{ftp}));
}

sub connect_count {
	my $self = shift;
	return $self->{_connect_count};
}

sub login {
	my $self = shift;

	$self->{login} = \@_;
	$self->{ftp}->login(@_);
}

sub authorize {
	my $self = shift;
	$self->{authorize} = \@_;
	$self->{ftp}->authorize(@_);
}

sub site {
	my $self = shift;
	$self->{ftp}->site(@_);
}

sub ascii {
	my $self = shift;
	$self->{mode} = 'ascii';
	$self->_auto_reconnect(sub { $self->{ftp}->ascii() || undef });
}

sub binary {
	my $self = shift;
	$self->{mode} = 'binary';
	$self->_auto_reconnect(sub { $self->{ftp}->binary() || undef });
}

sub rename {
	my $self = shift;
	my @a = @_;
	$self->_auto_reconnect(sub { $self->{ftp}->rename(@a) || undef });
}

sub delete {
	my $self = shift;
	my @a = @_;
	$self->_auto_reconnect(sub { $self->{ftp}->delete(@a) || undef });
}

sub cwd {
	my $self = shift;
	my @a = @_;
	my $ret = $self->_auto_reconnect(sub { $self->{ftp}->cwd(@a) || undef });
	if($ret){
		$self->{cwd} = $self->{ftp}->pwd() or die "Couldn't get directory after cwd\n";
	}
	$ret;
}

sub cdup {
	my $self = shift;
	my @a = @_;
	my $ret = $self->_auto_reconnect(sub { $self->{ftp}->cdup(@a) || undef});
	if($ret){
		$self->{cwd} = $self->{ftp}->pwd() or die "Couldn't get directory after cdup\n";
	}
	$ret;
}

sub pwd {
	my $self = shift;
	my @a = @_;
	$self->_auto_reconnect(sub { $self->{ftp}->pwd(@a)});
}

sub debug {
	my $self = shift;
	my @a = @_;
	$self->_auto_reconnect(sub { $self->{ftp}->debug(@a)});
}

sub rmdir {
	my $self = shift;
	my @a = @_;
	$self->_auto_reconnect(sub { $self->{ftp}->rmdir(@a) || undef});
}

sub mkdir {
	my $self = shift;
	my @a = @_;
	$self->_auto_reconnect(sub { $self->{ftp}->mkdir(@a) });
}

sub ls {
	my $self = shift;
	my @a = @_;
	my $ret = $self->_auto_reconnect(sub { $self->{ftp}->ls(@a) });
	return $ret ? (wantarray ? @$ret : $ret) : undef;
}

sub dir {
	my $self = shift;
	my @a = @_;
	my $ret = $self->_auto_reconnect(sub { $self->{ftp}->dir(@a) });
	return $ret ? (wantarray ? @$ret : $ret) : undef;
}

sub restart {
	my $self = shift;
	my @a = @_;
	$self->{restart} = \@a;
	$self->{ftp}->restart(@_);
}

sub retr {
	my $self = shift;
	my @a = @_;
	$self->_after_pcmd($self->_auto_reconnect(sub { $self->{ftp}->retr(@a) || undef }));
}

sub get {
	my $self = shift;
	my @a = @_;
	$self->_auto_reconnect(sub { $self->{ftp}->get(@a) });
}

sub mdtm {
	my $self = shift;
	my @a = @_;
	$self->_auto_reconnect(sub { $self->{ftp}->mdtm(@a) });
}

sub size {
	my $self = shift;
	my @a = @_;
	$self->_auto_reconnect(sub { $self->{ftp}->size(@a) });
}

sub abort {
	my $self = shift;
	$self->{ftp}->abort();
}

sub quit {
	my $self = shift;
	$self->{ftp}->quit();
}

sub hash {
	my $self = shift;
	my @a = @_;
	$self->{hash} = \@a;
	$self->{ftp}->hash(@_);
}

sub alloc {
	my $self = shift;
	my @a = @_;
	$self->{alloc} = \@a;
	$self->_auto_reconnect(sub { $self->{ftp}->alloc(@a) });
}

sub put {
	my $self = shift;
	my @a = @_;
	$self->_auto_reconnect(sub { $self->{ftp}->put(@a) });
}

sub put_unique {
	my $self = shift;
	my @a = @_;
	$self->_auto_reconnect(sub { $self->{ftp}->put_unique(@a) });
}

sub append {
	my $self = shift;
	my @a = @_;
	$self->_auto_reconnect(sub { $self->{ftp}->append(@a) });
}

sub unique_name {
	my $self = shift;
	$self->{ftp}->unique_name(@_);
}

sub supported {
	my $self = shift;
	my @a = @_;
	$self->_auto_reconnect(sub { $self->{ftp}->supported(@a) });
}

sub port {
	my $self = shift;
	my @a = @_;
	$self->{port} = \@a;
	$self->_auto_reconnect(sub { $self->{ftp}->port(@a) });
}

sub pasv {
	my $self = shift;
	my @a = @_;
	$self->{pasv} = \@a;
	$self->_auto_reconnect(sub { $self->{ftp}->pasv(@a) });
}

sub nlst {
	my $self = shift;
	my @a = @_;
	$self->_after_pcmd($self->_auto_reconnect(sub { $self->{ftp}->nlst(@a) }));
}

sub stou {
	my $self = shift;
	my @a = @_;
	$self->_after_pcmd($self->_auto_reconnect(sub { $self->{ftp}->stou(@a) }));
}

sub appe {
	my $self = shift;
	my @a = @_;
	$self->_after_pcmd($self->_auto_reconnect(sub { $self->{ftp}->appe(@a) }));
}

sub list {
	my $self = shift;
	my @a = @_;
	$self->_after_pcmd($self->_auto_reconnect(sub { $self->{ftp}->list(@a) }));
}

sub pasv_xfer {
	my $self = shift;
	$self->{ftp}->pasv_xfer(@_);
}

sub pasv_xfer_unique {
	my $self = shift;
	$self->{ftp}->pasv_xfer_unique(@_);
}

sub pasv_wait {
	my $self = shift;
	$self->{ftp}->pasv_wait(@_);
}

sub message {
	my $self = shift;
	$self->{ftp}->message(@_);
}

sub code {
	my $self = shift;
	$self->{ftp}->code(@_);
}

sub ok {
	my $self = shift;
	$self->{ftp}->ok(@_);
}

sub status {
	my $self = shift;
	$self->{ftp}->status(@_);
}

sub rget{
    my $ftp = shift;

    %options = (
                 ParseSub => \&parse_files,
                 SymLinkIgnore => 1,
                 @_,
                 InitialDir => $ftp->pwd
                );

    local %dirsSeen = ();
    local %filesSeen = ();

    if($options{SymlinkFollow}){
        $dirsSeen{ $ftp->pwd } = Cwd::cwd();
    }

    local $success = '';
    $ftp->_rget();

    return $success;
}

sub _rget {
    my($ftp) = shift;
    my @dirs;

    my @ls = $ftp->dir();
    my @files = $options{ParseSub}->( @ls );

    @files = grep { $_->filename =~ $options{MatchAll} } @files if $options{MatchAll};
    @files = grep { $_->filename !~ $options{OmitAll} } @files if $options{OmitAll};
    print STDERR join("\n", @ls), "\n" if $ftp->debug;

    my $remote_pwd = $ftp->pwd;
    my $local_pwd = Cwd::cwd();

    FILE:
    foreach my $file (@files){
        my $get_success = 1;
        my $filename = $file->filename();

        if ( $file->is_plainfile() ) {
            if(($options{MatchFiles} and $filename !~ $options{MatchFiles})
                or ($options{OmitFiles} and $filename =~ $options{OmitFiles} )){
                next FILE;
            }

            if ( $options{FlattenTree} and $filesSeen{$filename} ) {
                print STDERR "Retrieving $filename as ",
                             "$filename.$filesSeen{$filename}.\n"
                  if $ftp->debug;

                $get_success = $ftp->get( $filename,"$filename.$filesSeen{$filename}" );
            } else {
                print STDERR "Retrieving $filename.\n"
                  if $ftp->debug;

                $get_success = $ftp->get( $filename );
            }

            $filesSeen{$filename}++ if $options{FlattenTree};

            if ( $options{RemoveRemoteFiles} ) {
                if ( $options{CheckSizes} ) {
                    if ( -e $filename and ( (-s $filename) == $file->size ) ) {
                        $ftp->delete( $filename );
                        print STDERR "Deleting '$filename'.\n"
                          if $ftp->debug;
                    } else {
                        print STDERR "Will not delete '$filename': ",
                                     'remote file size and local file size ',
                                     "do not match!\n"
                          if $ftp->debug;
                    }
                } else {
                    if ( $get_success ) {
                        $ftp->delete( $filename );
                        print STDERR "Deleting '$filename'.\n"
                          if $ftp->debug;
                    } else {
                        print STDERR "Will not delete '$filename': ",
                                     "error retrieving file!\n"
                          if $ftp->debug;
                    }
                }
            }
        }
        elsif ( $file->is_directory() ) {

            if( (     $options{MatchDirs}
                  and $filename !~ $options{MatchDirs} )
                or
                (     $options{OmitDirs}
                  and $filename =~ $options{OmitDirs} )){

                next FILE;
            }

            if ( $options{SymlinkFollow} ) {
                $dirsSeen{"$remote_pwd/$filename"} = "$local_pwd/$filename";
                print STDERR "Mapping '$remote_pwd/$filename' to ",
                             "'$local_pwd/$filename'.\n";
            }

            push @dirs, $file;
        }
        elsif ( $file->is_symlink() ) {
            if ( $options{SymlinkIgnore} ) {
                print STDERR "Ignoring the symlink ", $filename, ".\n"
                  if $ftp->debug;
                if ( $options{RemoveRemoteFiles} ) {
                    $ftp->delete( $filename );
                    print STDERR 'Deleting \'', $filename, "'.\n"
                      if $ftp->debug;
                }
                next FILE;
            }

            if( (     $options{MatchLinks}
                  and $filename !~ $options{MatchLinks} )
                or
                (     $options{OmitLinks}
                  and $filename =~ $options{OmitLinks} )){

                next FILE;
            }

            print STDERR "Testing to see if $filename refers to a directory.\n"
              if $ftp->debug;
            my $path_before_chdir = $ftp->pwd;
            my $is_directory = 0;

            if ( $ftp->cwd($file->filename()) ) {
                $ftp->cwd( $path_before_chdir );
                $is_directory = 1;
            }

            if ( not $is_directory and $options{SymlinkCopy} ) {
                my $get_success;
                if ( $options{FlattenTree} and $filesSeen{$filename}) {
                    print STDERR "Retrieving $filename as ",
                                 $filename.$filesSeen{$filename},
                                 ".\n"
                      if $ftp->debug;

                    $get_success = $ftp->get($filename,
                                             "$filename.$filesSeen{$filename}");
                } else {
                    print STDERR "Retrieving $filename.\n"
                      if $ftp->debug;

                    $get_success = $ftp->get( $filename );
                }

                $filesSeen{$filename}++;

                if ( $get_success and $options{RemoveRemoteFiles} ) {
                    $ftp->delete( $filename );

                    print STDERR "Deleting '$filename'.\n"
                      if $ftp->debug;
                }
            } #end of if (not $is_directory and $options{SymlinkCopy}
            elsif ( $is_directory and $options{SymlinkFollow} ) {
                #we need to resolve the link to an absolute path

                my $remote_abs_path = path_resolve( $file->linkname(),
                                                    $remote_pwd,
                                                    $filename
                );

                print STDERR "'$filename' got converted to '",
                             $remote_abs_path, "'.\n";

                if (    $dirsSeen{$remote_abs_path}
                    or $remote_abs_path =~ s{^$options{InitialDir}}
                                            {$dirsSeen{$options{InitialDir}}}){

                    unless( $options{FlattenTree} ){
                        print STDERR "\$dirsSeen{$remote_abs_path} = ",
                                     $dirsSeen{$remote_abs_path}, "\n"
                          if $ftp->debug;

                        print STDERR "Calling convert_to_relative( '",
                                     $local_pwd, '/', $filename, "', '",
                                     (    $dirsSeen{$remote_abs_path}
                                       || $remote_abs_path ),
                                     "');\n"
                          if $ftp->debug;

                        my $rel_path =
                          convert_to_relative( "$local_pwd/$filename",
                                                  $dirsSeen{$remote_abs_path}
                                               || $remote_abs_path
                        );

                        print STDERR "Symlinking '$filename' to '$rel_path'.\n"
                          if $ftp->debug;

                        symlink $rel_path, $filename;
                    }

                    if ( $options{RemoveRemoteFiles} ) {
                        $ftp->delete( $filename );

                        print STDERR "Deleting '$filename'.\n"
                          if $ftp->debug;
                    }

                    next FILE;
                }
                else {

                    print STDERR "New directory to grab!\n"
                      if $ftp->debug;
                    push @dirs, $file;

                    $dirsSeen{$remote_abs_path} = "$local_pwd/$filename";
                    print STDERR "Mapping '$remote_abs_path' to '",
                                 "$local_pwd/$filename'.\n"
                      if $ftp->debug;

                }

            }

            elsif ( $options{SymlinkLink} ) {
                symlink $file->linkName(), $file->filename();

                if ( $options{RemoveRemoteFiles} ) {
                    $ftp->delete( $file->filename );

                    print STDERR "Deleting '$filename'.\n"
                      if $ftp->debug;
                }
                next FILE;
            }
        }

        $success .= "Had a problem retrieving '$remote_pwd/$filename'!\n"
          unless $get_success;
    }

    undef @files;

    DIRECTORY:
    foreach my $file (@dirs) {
        my $filename = $file->filename;

        unless ( $ftp->cwd($filename) ) {
            print STDERR 'Was unable to cd to ', $filename,
                         ", skipping!\n"
              if $ftp->debug;

            $success .= "Was not able to chdir to '$remote_pwd/$filename'!\n";
            next DIRECTORY;
        }

        unless ( $options{FlattenTree} ) {
            print STDERR "Making dir: ", $filename, "\n"
              if $ftp->debug;

            mkdir $filename, "0755";
            chmod 0755, $filename;

            unless ( chdir $filename ){
                print STDERR 'Could not change to the local directory ',
                             $filename, "!\n"
                  if $ftp->debug;

                $ftp->cwd( $remote_pwd );
                $success .= q{Could not chdir to local directory '}
                          . "$local_pwd/$filename'!\n";

                next DIRECTORY;
            }
        }

        my $remove;
        if ( $options{RemoveRemoteFiles} and $file->is_symlink() ) {
            $remove = $options{RemoveRemoteFiles};
            $options{RemoveRemoteFiles} = 0;
        }

        print STDERR 'Calling rget in ', $remote_pwd, "\n"
          if $ftp->debug;
        $ftp->_rget( );

        print STDERR 'Returned from rget in ', $remote_pwd, ".\n"
          if $ftp->debug;

        if ( $file->is_symlink() ) {
            $ftp->cwd( $remote_pwd );
            $options{RemoveRemoteFiles} = $remove;
        } else {
            $ftp->cdup;
        }

        chdir '..' unless $options{FlattenTree};

        if ( $options{RemoveRemoteFiles} ) {
            if ( $file->is_symlink() ) {
                print STDERR "Removing symlink '$filename'.\n"
                  if $ftp->debug;

                $ftp->delete( $filename );
            } else {
                print STDERR "Removing directory '$filename'.\n"
                  if $ftp->debug;

                $ftp->rmdir( $filename );
            }
        }
    }
}

sub rput{
	my $ftp = shift;

	%options = (
	       ParseSub => \&parse_files,
	       @_
	      );

	local %filesSeen = ();
	local $success = '';
	$ftp->_rput();

	return $success;
}

sub _rput {
    my($ftp) = shift;
    my @dirs;
    my @files = read_current_directory();

    print STDERR join("\n", sort map { $_->filename() } @files),"\n" if $ftp->debug;
    my $remote_pwd = $ftp->pwd;

    foreach my $file (@files){
        my $put_success = 1;
        my $filename = $file->filename();

        if ( $file->is_plainfile() ) {
            if ( $options{FlattenTree} and $filesSeen{$filename} ) {
                print STDERR "Sending $filename as ",
                             "$filename.$filesSeen{$filename}.\n"
                  if $ftp->debug;
                $put_success = $ftp->put( $filename,
                                         "$filename.$filesSeen{$filename}" );
            } else {
                print STDERR "Sending $filename.\n" if $ftp->debug;
                $put_success = $ftp->put( $filename );
            }

            $filesSeen{$filename}++ if $options{FlattenTree};

            if ( $options{RemoveLocalFiles} and $options{CheckSizes} ) {
                if ( $ftp->size($filename) == (-s $filename) ) {
                    print STDERR q{Removing '}, $filename,
                                 "' from the local system.\n"
                      if $ftp->debug;

                    unlink $file->filename();
                } else {
                    print STDERR "Will not delete '$filename': ",
                                 'remote file size and local file size',
                                 " do not match!\n"
                      if $ftp->debug;
                }
            }
            elsif( $options{RemoveLocalFiles} ) {
                print STDERR q{Removing '}, $filename,
                             "' from the local system.\n"
                  if $ftp->debug;
                unlink $file->filename();
            }
        }elsif ( $file->is_directory() ) {
            push @dirs, $file;
        }elsif ( $file->is_symlink() ) {
            if ( $options{SymlinkIgnore} ) {
                print STDERR "Not doing anything to ", $filename,
                             " as it is a link.\n"
                  if $ftp->debug;

                if ( $options{RemoveLocalFiles} ) {
                    print STDERR q{Removing '}, $filename,
                                 "' from the local system.\n"
                      if $ftp->debug;

                    unlink $file->filename();
                }
            }else{
                if ( -f $filename and $options{SymlinkCopy} ) {
                    if ( $options{FlattenTree} and $filesSeen{$filename}) {
                        print STDERR "Sending $filename as ",
                                     "$filename.$filesSeen{$filename}.\n"
                          if $ftp->debug;

                        $put_success = $ftp->put( $filename,
                                       "$filename.$filesSeen{$filename}" );

                    } else {
                        print STDERR "Sending $filename.\n"
                          if $ftp->debug;

                        $put_success = $ftp->put( $filename );
                    }

                    $filesSeen{$filename}++ if $options{FlattenTree};

                    if ( $put_success and $options{RemoveLocalFiles} ) {
                        print STDERR q{Removing '}, $filename,
                                     "' from the local system.\n"
                          if $ftp->debug;

                        unlink $file->filename();
                    }
                }elsif ( -d $file->filename() and $options{SymlinkFollow} ) {
                    push @dirs, $file;
                }
            }
        }
        $success .= "Had trouble putting $filename into $remote_pwd\n" unless $put_success;
    }

    undef @files;
    my $local_pwd  = Cwd::cwd();

    foreach my $file (@dirs) {
        my $filename = $file->filename();

        unless ( chdir $filename ){
            print STDERR 'Could not change to the local directory ',
                         $filename, "!\n"
              if $ftp->debug;

            $success .= 'Could not change to the local directory '
                      . qq{'$local_pwd/$filename'!\n};
            next;
        }

        unless( $ftp->cwd($filename) ){
            print STDERR "Making dir: ", $filename, "\n"
              if $ftp->debug;

            unless( $ftp->mkdir($filename) ){
                print STDERR 'Could not make remote directory ',
                             $filename, "!\n"
                  if $ftp->debug;

                $success .= q{Could not make remote directory '}
                         .  qq{$remote_pwd/$filename}
                          . qq{!\n};
            }

            unless ( $ftp->cwd($filename) ){
                print STDERR 'Could not change remote directory to ',
                             $filename, ", skipping!\n"
                  if $ftp->debug;

                $success .= qq{Could not change remote directory to '}
                          . qq{$remote_pwd/$filename}
                          . qq{'!\n};
                next;
            }
        }

        print STDERR "Calling rput in ", $local_pwd, "\n"
          if $ftp->debug;
        $ftp->_rput();

        #once we've recursed, we'll go back up a dir.
        print STDERR 'Returned from rput in ',
                     $filename, ".\n"
          if $ftp->debug;

        $ftp->cdup;

        if ( $file->is_symlink() ) {
            chdir $local_pwd;
            unlink $filename if $options{RemoveLocalFiles};
        } else {
            chdir '..';
            rmdir $filename if $options{RemoveLocalFiles};
        }
    }
}


sub rdir {
    my($ftp) = shift;

    %options = ( ParseSub => \&parse_files,
                 OutputFormat => '%p %lc %u %g %s %d %f %l',
                 @_,
                 InitialDir => $ftp->pwd
               );

    unless( $options{Filehandle} ) {
        Carp::croak("You must pass a filehandle when using rdelete/rls!");
    }

    local %dirsSeen = ();
    local %filesSeen = ();

    $dirsSeen{$ftp->pwd}++;
    local $success = '';

    $ftp->_rdir;

    return $success;
}

sub _rdir {
	my $ftp = shift;
	my @ls = $ftp->dir;
	print STDERR join("\n", @ls) if $ftp->debug;

	my(@dirs);
	my $fh;
	#if($options{nofilehandle} == 1){
	#	$fh = $options{Filehandle};
	#}else{
		$fh = $options{Filehandle};
	#}
	print $fh $ftp->pwd, ":\n" unless $options{FilenameOnly};

	my $remote_pwd = $ftp->pwd;
	my $local_pwd  = Cwd::cwd();

    LINE:
    foreach my $line ( @ls ) {
        my($file) = $options{ParseSub}->( $line );
        next LINE unless $file;
        my $filename = $file->filename;
        my $size = $file->size;

        if ( $file->is_symlink() and $ftp->cwd($filename) ) {
            $ftp->cwd( $remote_pwd );

            my $remote_abs_path = path_resolve( $file->linkname,
                                                $remote_pwd,
                                                $filename );

            print STDERR qq{'$filename' got converted to '$remote_abs_path'.\n};

            unless (    $dirsSeen{$remote_abs_path}
                     or $remote_abs_path =~ m%^$options{InitialDir}% ){

                push @dirs, $file;
                $dirsSeen{$remote_abs_path}++;

                if( $ftp->debug() ){
                    print STDERR q{Mapping '},
                                 $remote_abs_path,
                                 q{' to '},
                                 $dirsSeen{$remote_abs_path},
                                 ".\n";
                }
            }
        }elsif( $file->is_directory() ){
            push @dirs, $file;

            if ( $options{FilenameOnly} && $options{PrintType} ) {
                print $fh $remote_pwd, '/', $filename, " d\n";
            }

            next LINE if $options{FilenameOnly};
        }


        if( $options{FilenameOnly} ){
            print $fh $remote_pwd, '/', $filename;
            if ( $options{PrintType} ) {
                my $filetype;
                if ( $file->is_symlink() ) {
                    print $fh ' s'.' '.$size;
                } elsif ( $file->is_plainfile() ) {
                    print $fh ' f'.' '.$size;
                }
            }
            print $fh "\n";
        }
        else {
            print $fh $line, "\n";
        }
    }

    print $fh "\n" unless $options{FilenameOnly};

    foreach my $dir (@dirs){
        my $dirname = $dir->filename;

        unless ( $ftp->cwd( $dirname ) ){
            print STDERR 'Was unable to cd to ', $dirname,
                         " in $remote_pwd, skipping!\n"
              if $ftp->debug;
            $success .= qq{Was unable to cd to '$remote_pwd/$dirname'\n};
            next;
        }

        print STDERR "Calling rdir in ", $remote_pwd, "\n" if $ftp->debug;
        $ftp->_rdir( );

        print STDERR "Returned from rdir in ", $dirname, ".\n" if $ftp->debug;

        if ( $dir->is_symlink() ) {
            $ftp->cwd($remote_pwd);
        }else{
            $ftp->cdup;
        }
    }
}

sub rls {
	my $ftp = shift;
	return $ftp->rdir(@_, FilenameOnly => 1);
}

sub rdelete {
	my($ftp) = shift;

	%options = ( ParseSub => \&parse_files,
                @_
               );

	local $success = '';
	$ftp->_rdelete();

	return $success;
}

sub _rdelete {
	my $ftp = shift;
	my @dirs;
	my @ls = $ftp->dir;
	print STDERR join("\n", @ls) if $ftp->debug;
	my $remote_pwd = $ftp->pwd;

    foreach my $line ( @ls ){
        my($file) = $options{ParseSub}->($line);

        if ( $file->is_plainfile() or $file->is_symlink() ) {
            my $filename = $file->filename();
            my $del_success = $ftp->delete($filename);

            $success .= qq{Had a problem deleting '$remote_pwd/$filename'!\n}
              unless $del_success;
        }
        elsif ( $file->is_directory() ) {
            push @dirs, $file;
        }
    }

    foreach my $file (@dirs) {
        my $filename = $file->filename();

        unless ( $ftp->cwd( $file->filename() ) ){
            print STDERR qq{Could not change dir to $filename!\n}
              if $ftp->debug;
            $success .= qq{Could not change dir to '$remote_pwd/$filename'!\n};
            next;
        }

        print STDERR 'Calling _rdelete in ', $ftp->pwd, "\n"
          if $ftp->debug;
        $ftp->_rdelete( );

        print STDERR "Returned from _rdelete in ", $ftp->pwd, ".\n"
          if $ftp->debug;
        $ftp->cdup;

        $ftp->rmdir($file->filename())
          or $success .= 'Could not delete remote directory "'
                       . qq{$remote_pwd/$filename}
                       . qq{"!\n};
    }
}

sub read_current_directory {
	opendir THISDIR, '.' or die "Couldn't open ", getcwd();
	my $path = getcwd();
	my @to_return;

	foreach my $file ( sort readdir(THISDIR) ){
		next if $file =~ /^[.]{1,2}$/;
		my $file_obj;

        if( -l $file ){
            $file_obj = Net::FTP::Recursive::AutoReconnect::File->new(
                                                'symlink' => 1,
                                                filename  => $file,
                                                path      => $path,
                                                linkname  => readlink($file),
                                               );
        }elsif( -d $file ){
            $file_obj = Net::FTP::Recursive::AutoReconnect::File->new(
                                                        directory  => 1,
                                                        filename   => $file,
                                                        path       => $path,
                                                       );
        }elsif( -f $file ){
            $file_obj = Net::FTP::Recursive::AutoReconnect::File->new(
                                                        plainfile => 1,
                                                        filename  => $file,
                                                        path      => $path,
                                                       );
        }

        push @to_return, $file_obj if $file_obj;
    }

    closedir THISDIR;
    return @to_return;
}

sub parse_files {
    my(@to_return) = ();

    foreach my $line (@_) {
        next unless $line =~ /^
                               (\S+)\s+             #permissions
                                \d+\s+              #link count
                                \S+\s+              #user owner
                                \S+\s+              #group owner
                                (\d+)\s+              #size
                                \w+\s+\w+\s+\S+\s+  #last modification date
                                (.+?)\s*            #filename
                                (?:->\s*(.+))?      #optional link part
                               $
                              /x;

        my($perms, $size, $filename, $linkname) = ($1, $2, $3, $4);
        next if $filename =~ /^\.{1,2}$/;

        my $file;
        if($perms =~/^-/){
            $file = Net::FTP::Recursive::AutoReconnect::File->new( plainfile => 1,
                                                    filename  => $filename,
                                                    size  => $size );
        }elsif ($perms =~ /^d/) {
            $file = Net::FTP::Recursive::AutoReconnect::File->new( directory => 1,
                                                    filename  => $filename,
                                                    size  => $size );
        }elsif ($perms =~/^l/) {
            $file = Net::FTP::Recursive::AutoReconnect::File->new( 'symlink' => 1,
                                                    filename  => $filename,
                                                    linkname  => $linkname,
                                                    size  => $size );
        }else{
            next;
        }
        push(@to_return, $file);
    }

    return(@to_return);
}

sub path_resolve {
	my($link_path, $pwd, $filename) = @_;
	my $remote_pwd; #value to return

	if($linkMap{$pwd} and $link_path !~ m#^/#){
		$remote_pwd = $linkMap{$pwd} . '/' . $link_path;
	}elsif($link_path =~ m#^/#){
		$remote_pwd = $link_path;
	}else{
		$remote_pwd = $pwd;
		$remote_pwd =~ s#(?<!/)$#/#;
		$remote_pwd .= $link_path;
	}
	while ( $remote_pwd =~ s#(?:^|/)\.(?:/|$)#/# ) {}
	while ( $remote_pwd =~ s#(?:/[^/]+)?/\.\.(?:/|$)#/# ){}

	$filename =~ s#/$##;
	$remote_pwd =~ s#/$##;

	$pwd =~ s#(?<!/)$#/#;
	$linkMap{$pwd . $filename} = $remote_pwd;
	$remote_pwd;
}

sub convert_to_relative {
	my($link_loc, $realfile) = (shift, shift);
	my $i;
	my $result;
	my($new_realfile, $new_link, @realfile_parts, @link_parts);

	@realfile_parts = split m#/#, $realfile;
	@link_parts = split m#/#, $link_loc;

	for($i = 0; $i < @realfile_parts; $i++ ){
		last unless $realfile_parts[$i] eq $link_parts[$i];
	}
	$new_realfile = join '/', @realfile_parts[$i..$#realfile_parts];
	$new_link = join '/', @link_parts[$i..$#link_parts];

	if($i == 1){
		$result = $realfile;
	}elsif($i > $#realfile_parts and $i == $#link_parts){
		$result = '.';
	}elsif($i == $#realfile_parts and $i == $#link_parts){
		$result = $realfile_parts[$i];
	}elsif($i >= $#link_parts){
		$result = join '/', @realfile_parts[$i..$#realfile_parts];
	}else{
		$result = '../' x ($#link_parts - $i);
		$result .= join '/', @realfile_parts[$i..$#realfile_parts] if $#link_parts - $i > 0;
	}
	return $result;
}

package Net::FTP::Recursive::AutoReconnect::File;

use vars qw/@ISA/;
use Carp;

@ISA = ();

sub new {
	my $pkg = shift;
	my $self = { plainfile => 0,
                 directory => 0,
                 'symlink' => 0,
                 @_
               };

	croak 'Must set a filename when creating a File object!' unless defined $self->{filename};

	if($self->{'symlink'} and not $self->{linkname}){
		croak 'Must set a linkname when creating a File object for a symlink!';
	}

	bless $self, $pkg;
}

sub linkname {
	return $_[0]->{linkname};
}

sub filename {
	return $_[0]->{filename};
}

sub size {
	return $_[0]->{size};
}

sub is_symlink {
	return $_[0]->{symlink};
}

sub is_directory {
	return $_[0]->{directory};
}

sub is_plainfile {
	return $_[0]->{plainfile};
}

1;
__END__

=head1 NAME

Net::FTP::Recursive::AutoReconnect - FTP client class with recursive and automatic reconnect on failure

=head1 SYNOPSIS

	use Net::FTP::Recursive::AutoReconnect;

	my $host = 'localhost';
	my $timeout = '10';

	my $user = 'username';
	my $pass = 'passwort';
	my $ftp = Net::FTP::Recursive::AutoReconnect->new($host, Timeout => $timeout, Debug => 0) or warn "$user: Cannot connect to $host: $@";
	$ftp->login($user,$pass) or warn "$user $pass: Cannot login ", $ftp->message;
	$ftp->cwd("/") or warn "$user: Cannot change working directory ", $ftp->message;

	my $writefh;
	my $fh;
	open($fh,">",\$writefh);
	binmode($fh);

	print $ftp->rdir( FilenameOnly => 1, Filehandle => $fh, PrintType => 1 );
	$ftp->quit;
	close($fh);
	print $writefh;

=head1 DESCRIPTION

FTP client class with recursive and automatic reconnect on failure

=head1 SEE ALSO

L<Net::FTP>.

=head1 COPYRIGHT

see L<Net::FTP>, L<Net::FTP::Recursive> and L<Net::FTP::AutoReconnect>

=cut
