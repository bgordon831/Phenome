#!/usr/bin/perl
use strict;
use CXGN::DB::Connection;
use CXGN::Phenome::Individual;
use CXGN::Phenome::Population;
use CXGN::People::Person;
use CXGN::DB::InsertDBH;

use Getopt::Std;


our ($opt_H, $opt_D, $opt_v,  $opt_t, $opt_i, $opt_u);

getopts('H:D:u:tvi:');

my $dbhost = $opt_H;
my $dbname = $opt_D;
my $infile = $opt_i;
my $sp_person=$opt_u;

if (!$infile) {
    print STDOUT "\n You must provide an  infile!\n";
    usage();
}

if (!$dbhost && !$dbname) { 
    print  STDOUT "Need -D dbname and -H hostname arguments.\n"; 
    usage();
}

my $dbh = CXGN::DB::InsertDBH->new( { dbhost=>$dbhost,
				      dbname=>$dbname,
                                      dbschema => 'phenome', 
                                   } );

#my $person=CXGN::People::Person->new_with_name($dbh, $sp_person);
my $sp_person_id=CXGN::People::Person->get_person_by_username($dbh, $sp_person);
if (!$sp_person_id) {
    print STDOUT "User name $sp_person does not exist in database $dbname on host $dbhost!\n\n";
    usage();
}

eval {
    my $infile=open (my $infile, $opt_i) || die "can't open file $infile!\n";   #./epplant.txt
    
    #skip the first line
    <$infile>;
    
    
    my $population_name = "Asian eggplant landraces and allied species";
    my $desc = "Accessions represented in this germplasm collection are eggplant landraces and closely-related species from various regions of Asia (with a few exceptions).  There are four sources of these collections.  The INRA (France), the AVRDC (Taiwan), the USDA ARS-GRIN (US), and NYBG (US).  These germplasm collections were selected for studying the biodiversity of Asian eggplants.
Some of the INRA collections are divided by group.  These groups refer to Richard Lester’s classification of eggplants and theory of their domestication.  This classification is not reflected in the other germplasm collections. 
Several of the accessions have new taxonomic determinations that may differ from the information in the primary germplasm databases (such as the GRIN database).  These new determinations were made by Michael Nee and Rachel Meyer (NYBG).  
Please contact Rachel Meyer (Rmeyer\@nybg.org) for information about the collection or if you are interested in germplasm requests or donating germplasm.";
    
    
    my $common_name_id;
    my $population = CXGN::Phenome::Population->new_with_name($dbh, $population_name);
    if (!$population) {
	
	my $common_name= 'Eggplant';
	my $org_query= "SELECT common_name_id FROM sgn.common_name WHERE common_name ilike ?";
	my $org_sth=$dbh->prepare($org_query);
	$org_sth->execute($common_name);
	($common_name_id)=$org_sth->fetchrow_array();
	
	$population = CXGN::Phenome::Population->new($dbh);
	$population->set_name($population_name);
	$population->set_description($desc);
	$population->set_common_name_id($common_name_id);
	$population->set_sp_person_id($sp_person_id);
	$population->store();
    }
    
    while (my $line=<$infile>) {
	
	
	my @fields = split "\t", $line;
	my $cname= $fields[0];
	my $accession = $fields[1];
	my $organism= $fields[2];
	my $origin = $fields[3];
	my $comments = $fields[4];
	my $source= $fields[5];
	my $photo_acc = $fields[6];
	chomp $photo_acc;
	
	my $description = "";
	$description .= "Common name: $cname\n" if $cname;
	$description .= "Organism: $organism\n" if $organism;
	$description .= "Origin: $origin\n" if $origin;
	$description .= "Source database: $source\n" if $source;
	$description .= $comments;
	
	my $date= 0;
	if ($date ==0) {$date= 'now()'};
	$date=~ s/^(\d{8})(\d{6})/\1 \2-03/;
	chomp $date;
	#print STDOUT "$common_name (id = $common_name_id),  $cname, $accession\n";
	
	
	my $ind= CXGN::Phenome::Individual->new($dbh);
	my @exists= CXGN::Phenome::Individual->new_with_name($dbh, $accession);
	$ind->set_name($accession);
	$ind->set_description($description);
	$ind->set_sp_person_id($sp_person_id);
	$ind->set_population_id($population->get_population_id());
	$ind->set_common_name_id($common_name_id);
	if (!@exists && $description) {
	    print STDOUT "$accession  $description \n";
	    $ind->store();
	    $ind->add_individual_alias($photo_acc, $sp_person_id) if $photo_acc;
	    
	}else { print STDOUT "individual name exists ($exists[0] , $accession) !\n "; }
	
    }
};   

if($@) {
    print $@;
    print"Failed; rolling back.\n";
    $dbh->rollback();
}else{ 
    print"Succeeded.\n";
    if (!$opt_t) {
	print STDOUT "committing ! \n";
        $dbh->commit();
    }else{
	print STDOUT "Rolling back! \n";
        $dbh->rollback();
    }
}


sub usage { 
    print STDOUT "Usage: load_eggplant_acc.pl -D dbname [ cxgn | sandbox ]  -H dbhost -t [trial mode ] -i input file -u sgn username \n";
    exit();
}
