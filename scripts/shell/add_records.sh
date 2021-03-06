#! /bin/bash
. ~/.bashrc
. ~/.lrgpaths

########
### Add new pending LRG records from the Git repository to the public and private ftps
### Will also add lines to the end of a release notes file

# Relevant paths
rootpath=${LRGROOTDIR}/lrg-xml/
pubpath=${PUBFTP}
pvtpath=${PVTFTP}
relnotes=${LRGROOTDIR}/lrg-ftp/public/relnotes.txt.new

echo -n "Do you have all the required xml files checked out and present in ${rootpath} (y/n)? "
read -e go
[ "$go" == "y" ] || exit

# Write the relnotes 
d=`date +%d-%b-%Y`
echo "LRG release n.n.n.n (${d})

There are PUBLIC LRG entries
There are PENDING pending LRG entries

### Notes
" > ${relnotes}

# Loop over the LRG records in the Git path. Skip them in case they exist in the published or pending directories
for path in ${rootpath}/LRG_*.xml
do
  name=`basename ${path}`
  lrgid=${name/.xml/}
  hgnc=`lrg_gene_name ${path}`
  if [ -e ${pubpath}/${name} -o -e ${pubpath}/pending/${name} ]
  then
    echo "Skipping ${lrgid} (${hgnc}) since it is already uploaded to the public ftp server"
  else
    echo "Uploading ${lrgid} (${hgnc})"
    dest=${pubpath}/pending/${name}
    cp ${path} ${dest}
    chmod 644 ${dest}
    dest=${pvtpath}/Pending/${name}
    cp ${path} ${dest}
    chmod 644 ${dest}
    echo "# Pending LRG record ${lrgid} (${hgnc}) added" >> ${relnotes}
  fi
done

# Grab the number of entries and edit it into the relnotes file
pub=`ls ${pubpath}/LRG_*.xml | wc -l`
pend=`ls ${pubpath}/pending/LRG_*.xml | wc -l`
sed -rie "s/PUBLIC/${pub}/" ${relnotes}
sed -rie "s/PENDING/${pend}/" ${relnotes}
