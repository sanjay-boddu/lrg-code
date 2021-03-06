package LRG::Pipeline::FinishIndexes;

use strict;
use warnings;
use JSON;

use base ('Bio::EnsEMBL::Hive::Process');

sub run {
  my $self = shift;

  my $new_xml_dir     = $self->param('new_xml_dir');
  my $ftp_dir         = $self->param('ftp_dir');
  my $index_suffix    = $self->param('index_suffix');
  my $lrg_index_json  = $self->param('lrg_index_json');
  my $lrg_diff_prefix = $self->param('lrg_diff_prefix');
  my $lrg_search_file = $self->param('lrg_search_file');
  my $assemblies      = $self->param('assemblies');

  my $tmp_dir   = "$new_xml_dir/index";
  my $index_dir = "$ftp_dir/.lrg_index";
  my $data_dir = "$ftp_dir/data_files";

  # Move the indexes from the temporary directory to the new directory
  if ($tmp_dir ne $index_dir) {
    `cp $tmp_dir/LRG_*$index_suffix.xml $index_dir`;
  }
  
  ## JSON ##
  # Get the JSON single index files
  my $dh;
  my @json_files;
  opendir($dh,$tmp_dir);
  warn("Could not process directory $tmp_dir") unless (defined($dh));
  while (my $file = readdir($dh)) {
    next unless ($file =~ m/\.json$/);
    push(@json_files, $file);
  }
  closedir($dh);

  my %autocomplete;
  open JSON, "> $tmp_dir/$lrg_index_json" || die $!;
  print JSON "[";
  # Loop over the files in the directory and open the JSON files
  my $count_json_entries = 0;
  my $max_json_entries_per_line = 100;
  my $json_line_content = '';

  foreach my $file (sort(@json_files)) {

    open F, "< $tmp_dir/$file" || die $!;
    while (<F>) {
      chomp $_;
      
      if ($count_json_entries == $max_json_entries_per_line) {
        print JSON "$json_line_content,\n";
        $json_line_content = '';
        $count_json_entries = 0;
      }
      
      my $json_data  = $_;
      
      $json_line_content .= ',' if ($json_line_content ne '');
      $json_line_content .= $json_data;
      $count_json_entries ++; 
      
      # Get autocomplete data
      my $json_obj = decode_json $json_data;
      $autocomplete{$json_obj->{'id'}} = 1;
      $autocomplete{$json_obj->{'symbol'}} = 1;
      $autocomplete{$json_obj->{'status'}} = 1;
      foreach my $term (@{$json_obj->{'terms'}}) {
        $autocomplete{$term} = 1;
      }
    }
    close(F);
    `rm -f $tmp_dir/$file`;
  }

  print JSON "$json_line_content" if ($json_line_content ne '');
  print JSON "]";
  close(JSON);

  ## LRG SEARCH TERMS ##
  open TERMS, "> $tmp_dir/$lrg_search_file" || die $!;
  foreach my $term (sort(keys(%autocomplete))) {
    print TERMS "$term\n";
  }
  close(TERMS);
  
  
  ## DIFF ##
  # Get the DIFF single files
  foreach my $assembly (@$assemblies) {
    open DIFF, "> $tmp_dir/$lrg_diff_prefix$assembly.txt" || die $!;
    
    opendir($dh,$tmp_dir);
    warn("Could not process directory $tmp_dir") unless (defined($dh));
    
    # Loop over the files in the directory and open the DIFF txt files
    while (my $file = readdir($dh)) {
      next unless ($file =~ m/\d+_diff_$assembly\.txt$/);
      open F, "< $tmp_dir/$file" || die $!;
      while (<F>) {
        print DIFF "$_";
      }
      close(F);
    }
    closedir($dh);
    close(DIFF);
  }
  

  # Remove LRG individual json files from the new directory
  # Move the global json index file to the new directory
  if ($tmp_dir ne $index_dir) {
    `rm -f $index_dir/LRG_*_index.json`; # Double check
    `rm -f $index_dir/LRG_*_diff.txt`;   # Double check
    `mv $tmp_dir/$lrg_index_json $data_dir`;
    foreach my $assembly (@$assemblies) {
      `mv $tmp_dir/$lrg_diff_prefix$assembly.txt $data_dir`;
    }
    `mv $tmp_dir/$lrg_search_file $data_dir`;
  }
}
1;
