apt-get --purge remove -y postgresql-9.3
apt-get update -y && apt-get install -y postgresql-9.6 python2.7
cp /workdir/scripts/bk_tests/pb_hba.conf /etc/postgresql/9.6/main/pg_hba.conf
rm /bin/python
ln -s /usr/bin/python2.7 /bin/python
asdf local erlang 18.3
asdf local ruby 2.5.5
gem install bundler --version '~> 1.17' --no-document
cpanm --notest --quiet --local-lib=$HOME/perl5 local::lib && eval $(perl -I ~/perl5/lib/perl5/ -Mlocal::lib)
cpanm --notest --quiet App::Sqitch
service postgresql restart
