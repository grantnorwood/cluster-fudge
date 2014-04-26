--
-- Sample lsyncd.lua configuration file.
--

settings {
   logfile = "/var/log/lsyncd/lsyncd.log",
   statusFile = "/var/log/lsyncd/lsyncd-status.log",
   statusInterval = 20
}

-- First Target
sync {
    default.rsync,
    source = "/var/www/vhosts/",
    target = "10.x.x.1:/var/www/vhosts/", -- Enter your IP!
	-- exclude = "/var/www/vhosts/example.org/wp-content/upgrade",
	excludeFrom = "/etc/lsyncd.exclude", -- loads exclusion rules from this file, one rule per line.
    rsync = {
        compress = true,
        acls = true,
        verbose = true,
        rsh = "/usr/bin/ssh -p 22 -o StrictHostKeyChecking=no"
    }
}

-- Second Target
sync {
    default.rsync,
    source = "/var/www/vhosts/",
    target = "10.x.x.2:/var/www/vhosts/", -- Enter your IP!
	-- exclude = "/var/www/vhosts/example.org/wp-content/upgrade",
	excludeFrom = "/etc/lsyncd.exclude", -- loads exclusion rules from this file, on rule per line
    rsync = {
        compress = true,
        acls = true,
        verbose = true,
        rsh = "/usr/bin/ssh -p 22 -o StrictHostKeyChecking=no"
    }
}