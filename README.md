# fastfilezilla
FileZilla with modifications to increase responsiveness

## FileZilla for Windows, with responsiveness improvements

This is **not** a fork of FileZilla. This is simply a repository with a simple patch
to improve the responsiveness of FileZilla, and a script that compiles it from
source and generates an installer file.

The script here cross-compiles FileZilla for Windows on Debian-based Linux.

For convenience, a binary download of running this script (3.62.2 upstream) is provided.
The binary is not signed.

## Background

FileZilla has a known issue that it can hang for a long time when navigating
SFTP hosts where idle connections are dropped without both peers being properly informed.
This is common with many cloud providers, such as DigitalOcean, DreamHost, etc.

As a user, what you'll notice is that if you come back to an open FileZilla connection
and try to change directories, it will hang for a long time before eventually aborting
the current connection and logging in again. You may notice this on some machines, but not others
(e.g. not with hosts on your own LAN).

If you SFTP files many times a day, the net result of this is that *this will waste a lot of your time*,
since you may have to wait a long time for FileZilla to abort stale connections and reconnect.
I found that the official version of FileZilla was wasting hours of my time over the course
of just a couple months. These modifications reduce the amount of time wasted.

The author of FileZilla has not allowed users to change this value since the real problem
is firewalls that are improperly dropping connections without informing both peers,
and choosing a setting that is too low could cause connections to fail altogether (see **WARNING**).
This is small consolation, however, if you use servers affected by this issue.
This modification to FileZilla simply allows users to choose any arbitrary value,
allowing end users to choose the setting that works best for them.

I am hopeful that some day the author of FileZilla may change his mind and allow
this capability in the official version, but until then, that is what this is here for.

### WARNING

You should not choose a value of `3` or lower for the timeout value (even though this is possible
with this version). This is because this is used for initial connections and reconnections, too,
not merely for navigating an active connection. Thus, this should be set to just slightly longer
than it takes to establish a connection to any server that you use (since this is a global setting).

A good value for this setting might be `4` or `5`. You will have to test this for yourself.
The lower this value, the faster reconnects on stale
connections will be. However, the greater the chance it might prevent you from connecting to
the server at all in the first place (it will be obvious if this happens). On the flipside, the
higher the value, the longer it will take for FileZilla to abort a stale connection and reconnect.

Note that the official FileZilla only allows you to set this as low as `10`.
