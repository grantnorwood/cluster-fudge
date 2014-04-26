/** 
 * 
 * Set the default backend.  In this case, Apache is running on port 8080 of the same machine.
 * 
 */
backend default {
    .host = "127.0.0.1";
    .port = "8080";
}

/**
 * 
 * Set the backend master node.  (When Varnish is running as a load-balancer on a separate server.)
 * 
 */
#backend master {
#       .host = "10.182.160.58";
#       .port = "80";
#}

acl purge {
   "localhost";
   "web1";
   "web2";
   "web3";
}

/**
 * 
 * The first function executed after Varnish has decoded the request.
 * (@see https://www.varnish-software.com/static/book/VCL_Basics.html#vcl-vcl-recv)
 * 
 */
sub vcl_recv {
    
    if (req.request == "PURGE" || req.request == "BAN") {
        if (!client.ip ~ purge) {
            error 405 "Not allowed.";
        }
        
        ban("req.http.host == " + req.http.host);
        error 200 "Purged.";
    }

    # Only on first VCL loop.
    if (req.restarts == 0) {

        # Pass the client's IP on in the X-Forwarded-For HTTP header.
        if (req.http.x-forwarded-for) {
            set req.http.X-Forwarded-For =
            req.http.X-Forwarded-For + ", " + client.ip;
        } else {
            set req.http.X-Forwarded-For = client.ip;
        }

    }

    # Never cache the admin pages, login pages, the server-status page, POST requests, or WordPress post previews.
    if (req.url ~ "wp-(admin|login)" || req.http.Content-Type ~ "multipart/form-data" || req.url ~ "preview=true")
    {
        #Only if using Varnish as a load-balancer.
        #set req.backend = master;
        
        return(pass);
    }

    # Always cache these images & static assets, and remove their cookies.
    if (req.request == "GET" && req.url ~ "\.(css|js|gif|jpg|jpeg|bmp|png|ico|img|tga|wmf|pdf|zip|woff|eot|ttf|svg)$") {
        remove req.http.cookie;
        return(lookup);
    }

    # Cache GET requests for xmlrpc.php and wlmanifest.xml, and remove their cookies.
    if (req.request == "GET" && req.url ~ "(xmlrpc.php|wlmanifest.xml)") {
        remove req.http.cookie;
        return(lookup);
    }

    # Do not cache robots.txt.
    if (req.url ~ "robots.txt")
    {
        #Only if using Varnish as a load-balancer.
        #set req.backend = master;

        return(pass);
    }

    # Never cache POST requests.
    if (req.request == "POST")
    {
        return(pass);
    }

    # DO cache this ajax request.
    if(req.http.X-Requested-With == "XMLHttpRequest" && req.url ~ "recent_reviews")
    {
        return (lookup);
    }

    # Do NOT cache these ajax requests.
    if(req.http.X-Requested-With == "XMLHttpRequest" || req.url ~ "nocache" || req.url ~ "(control.php|wp-comments-post.php|wp-login.php|bb-login.php|bb-reset-password.php|register.php)")
    {
        return (pass);
    }

    # Rename the WP test cookie with "wpjunk" so we can better handle other "wordpress_" cookies later.
    if (req.http.Cookie && req.http.Cookie ~ "wordpress_") {
        set req.http.Cookie = regsuball(req.http.Cookie, "wordpress_test_cookie=", "; wpjunk=");
    }

    # Strip out all analytics cookies, they're only needed for the client which talks to Google Analytics.
    if (req.http.Cookie) {
        set req.http.Cookie = regsuball(req.http.Cookie, "(^|; ) *__(utm.|atuvc)=[^;]+;? *", "\1");
        if (req.http.Cookie == "") {
            remove req.http.Cookie;
        }
    }

    # Strip cookies for the homepage to really make it cacheable.
    if (req.url ~ "^/$") {
        unset req.http.cookie;
    }

    # Parse accept encoding rulesets to make it look nice.
    if (req.http.Accept-Encoding) {
        if (req.http.Accept-Encoding ~ "gzip") {
            set req.http.Accept-Encoding = "gzip";
        } elsif (req.http.Accept-Encoding ~ "deflate") {
            set req.http.Accept-Encoding = "deflate";
        } else {
            # unkown algorithm
            remove req.http.Accept-Encoding;
        }
    }

    #
    # Don't cache authenticated sessions (e.g., logged into WordPress).
    # Because PHPSESSID is specified, this will cause nothing to be cached 
    # if PHP sessions are in use!
    # 
    # Consider only passing when the "wordpress_" auth cookies are found, and 
    # ignore PHPSESSID so that non-logged-in visitors are cached properly.
    #
    #if (req.http.Cookie && req.http.Cookie ~ "(wordpress_|PHPSESSID)") {
    #    return(pass);
    #}

    return(lookup);
}

sub vcl_hash {
    hash_data(req.url);
    if (req.http.host) {
        hash_data(req.http.host);
    } else {
        hash_data(server.ip);
    }
    return (hash);
}

sub vcl_hit {
    if (req.request == "PURGE" || req.request == "BAN") {
        error 200 "Purged.";
    }
}

sub vcl_miss {
    if (req.request == "PURGE") {
        error 404 "Not in cache.";
    }
    if (!(req.url ~ "wp-(login|admin)")) {
        unset req.http.cookie;
    }
    if (req.url ~ "^/[^?]+.(jpeg|jpg|png|gif|ico|js|css|txt|gz|zip|lzma|bz2|tgz|tbz|html|htm|woff|eot|ttf|svg)(\?.|)$") {
        unset req.http.cookie;
        set req.url = regsub(req.url, "\?.$", "");
    }
    if (req.url ~ "^/$") {
        unset req.http.cookie;
    }
}

sub vcl_fetch {
    if (req.url ~ "^/$") {
        unset beresp.http.set-cookie;
    }
    #if (!(req.url ~ "wp-(login|admin)")) {
    #    unset beresp.http.set-cookie;
    #}
}

sub vcl_deliver {
  if (obj.hits > 0) {
    set resp.http.X-Cache = "HIT";
    set resp.http.X-Cache-Hits = obj.hits;
  } else {
    set resp.http.X-Cache = "MISS";
  }
}
