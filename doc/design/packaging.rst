
status: Pre-Draft

Figure out packaging? 
---------------------

	- audit source to ensure full copyright headers applied.
	- the real command line interface.... uptil now was just working stuff.
	- what documentation should be available.
	- what packages should be built.


Goals
-----

Can we make it really easy to build a ddsr node for techies to deploy a server ?
so it is easy for others to adopt.   Recipe for a standlone single node config.

	- this would be linux only,
	- either a dpkg or two (client & server?)
	- a docker container?

Make it easy for mortals to install the client.
need self-contained Windows install (an .exe) folks can download.
because many clients in various departments use Windows as clients,
and many data sources may use Windows also.

client package, if separate, would be just sr_post, sr_subscribe, sr_log...
sr_watch... hmm... server package would have a dep on rabbit? but client no.

pythonistas would probably find pypi the easiest. (on an installed python, just run:

    pypi install metpx-sarracenia

For internal use, ubuntu debs are the obvious choice.
    apt-get install metpx-sarracenia-server

for NRC, many users of Centos, so need RPMS.
    yum install metpx-sarracenia-server

The repositories likely are best placed on the internet, because we cannot depend
on clients being in locations accessible to Econet.

for Windows... need to talk with Stef, perhaps just document the complicated
baseline procedure, and improve over time.



Release Process
---------------

What we need is a first procedure that walks through making packages:

- git branch (create a release branch off of master....)
- Makefile sets the versioning information from the branch (git query?)
  puts that in the man pages, and somewhere the python can get to.
- apparently python setup has an ''upload'' so once it is registered
  on Pypi, python3 setup.py sdist upload will do id.
- using the same setup.py, Khosrow already built a dpkg builder.
  user



How to do Languages & Messaging
-------------------------------

Need English & French 
just keep it in code, no natural language?
There's fabulous ones: http://en.wikipedia.org/wiki/List_of_HTTP_status_codes

metpx-sarracenia-server
	- depends: rabbitmq.
	- configuration sugar, to create a working/secure default to just start using.
	- sr_sarra, and all the other components...
		log, and whatever.
		

metpx-sarracenia-client
	- sr_subscribe (dd_subscribe)  -
		should sr_subscribe accept it's config file on standard input?
	- sr_post
	- sr_watch
	- sr_send...


there might be a meta-client... one that invokes the others appropriately...
	sr_cp -broker amqp://mygroup@ddsr/ -threads 5  <operation>  <source> [<srcurl>] <dest>
		-broker says what the URL of the AMQP broker is.
		-threads says how many local instances to start.::

		<operation>

                post4pickup  -- sr_post, and the switch is expected to pull
                	-- requires <srcurl> to show URL remote will use to fetch.
                        fires off: just the sr_post -threads ignored.

                post2send    -- sr_post, then have local threads to send to sftp destination.
                        sftp destination is likely a 'source' for the switch, triggering further fwding ...
                        fires off: 1 sr_post and a 5 sr_sends, as appropriate.

                subscribe    -- sr_subscribe, but with n local instances.
                        fires off: 5 sr_sends, as appropriate.

                       fires off 5 sr_subscribes, or 
		
		
	
Dunno. We probably need to try a bunch out and see what sticks?


Windows
~~~~~~~

Packaging for Windows has particular issues because of a clash between the source
distribution norm on open source, vs. the binary distribution norm on Windows.   In
python packages this bites because, PyCrypto has portions of it implemented in C, so
standard installation means compiling that portion of the module, which creates a
dependency on a C-compiler for every installation.  Given the lack of consistency
in build environments on windows, one needs to obtain the build environment that
matches what was used to build the python interpreter.  google search ´install pycrypto Windows´
for more ample discussion.

Lack of dependency management also bites, too much assembly required (install amqplib, paramiko, etc...)
this is all easily taken care of on linux, but beyond the ability of non-technical users on Windows.


One way around it, use nuitka, to compile all depedendencies into a single binary package, put that in an MSI.

That does not solve the pycrypto compilation problem though.

One could modify paramiko to use a pure python implementation of pycrypto:

https://github.com/doegox/python-cryptoplus

compile that with nuitka.  to give a full package.


