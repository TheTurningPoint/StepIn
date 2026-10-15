insert into settings(org) values ('ttp'),('other');
insert into residents(id,name,role,house,status,org,phase,pin_hash) values
 ('o1','Olive Owner','owner',null,'active','ttp',null,extensions.crypt('1111',extensions.gen_salt('bf'))),
 ('mA','Mary A','manager','A','active','ttp',null,extensions.crypt('2222',extensions.gen_salt('bf'))),
 ('mB','Bob B','manager','B','active','ttp',null,'x'),
 ('mX','Max Gone','manager','A','discharged','ttp',null,'x'),
 ('rA1','Rae One','resident','A','active','ttp',1,extensions.crypt('3333',extensions.gen_salt('bf'))),
 ('rA2','Ray Two','resident','A','active','ttp',2,'x'),
 ('rB1','Rob Bee','resident','B','active','ttp',1,'x'),
 ('rX','Rex Gone','resident','A','discharged','ttp',1,'x'),
 ('z1','Zed Other','resident','A','active','other',1,'x');
insert into drug_tests(id,resident_id,house,org,result) values ('dA1','rA1','A','ttp','neg'),('dA2','rA2','A','ttp','pos'),('dB1','rB1','B','ttp','neg');
insert into incidents(id,resident_id,house,org) values ('iA2','rA2','A','ttp');
insert into grievances(id,resident_id,house,org,status) values ('gA1','rA1','A','ttp','open'),('gA2','rA2','A','ttp','open'),('gAnon',null,'A','ttp','open');
insert into chores(id,resident_id,house,org,title) values ('cA1','rA1','A','ttp','dishes'),('cA2','rA2','A','ttp','trash');
insert into resident_documents(id,resident_id,house,org,status,template_file_path) values ('rdA1','rA1','A','ttp','pending','ttp/t1_rules.pdf'),('rdA2','rA2','A','ttp','pending','ttp/t1_rules.pdf');
insert into document_templates(id,org,file_path,name) values ('t1','ttp','ttp/t1_rules.pdf','Rules');
insert into storage.objects(bucket_id,name) values ('documents','ttp/t1_rules.pdf'),('documents','ttp/rdA2_signed.pdf'),('documents','ttp/rdA1_signed.pdf');
update resident_documents set signed_file_path='ttp/rdA1_signed.pdf' where id='rdA1';
insert into checkins(id,resident_id,house,org) values ('kA1','rA1','A','ttp'),('kA2','rA2','A','ttp');
insert into curfew_log(id,resident_id,house,org,action) values ('clA2','rA2','A','ttp','in');
insert into events(id,org,house,title) values ('eA','ttp','A','A event'),('eB','ttp','B','B event'),('eAll','ttp',null,'all');
