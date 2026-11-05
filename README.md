# FireworksWebService

The web front end (Perl CGI scripts and UI5 pages) for the cmsShowWeb event display service at
<https://fireworks.cern.ch/cmsShowWeb/>. These files are deployed in `/var/www/html/cmsShowWeb/`.
`fireworks.cern.ch` is a DNS alias for **vocms0102** (production). **vocms0101** is the development host.

The scripts do not display events themselves. They talk to the `cmsShowWebService.exe` daemons
(FireworksWeb, run from `~viz/Service/runservice.sh`) over a local TCP socket. They then redirect the
browser to the cmsShowWeb session that the daemon forks.

## Request flow

```
browser ──► service.pl ──report_usage──► cmsShowWebService :6666
              │  renders ui5-common-gateway.html
              ▼
        user picks a file / sample / geometry
              ▼
        revetor-frontend.pl?load_file=…[&port=6669]
              │  {"action":"load", …} JSON
              ▼
        cmsShowWebService :6666 (CMSSW_17_X and older data)
                          :6669 (CMSSW_20_X / io_v1 data)
              │  forks cmsShowWeb.exe and replies {port, dir, key}
              ▼
        302 redirect ──► https://<host>/host<port>/<dir>?token=<key>
```

## Files

| File | Purpose |
|------|---------|
| `revetor-yuxiao.pl` | Entry page. It is deployed as **`service.pl`** (a plain copy) and is also symlinked as `revetor-yuxiao.pl`. It sends `report_usage` to port 6666 and puts the reply into `ui5-common-gateway.html` (it replaces the `MARK` and `MACHINE` placeholders). If the backend does not answer, it shows a "Backend Unavailable" page. |
| `ui5-common-gateway.html` | The main UI5 page. It lets the user pick an EOS file or an AAA (xrootd) file. It has these options: FW config, reco geometry (`--geom`) and simulation geometry (`--simGeo`). It has a radio button **"CMSSW_17_X data or older" / "CMSSW_20_X"**; CMSSW_20_X appends `&port=6669`. It also has sample buttons and an **Open Geometry Browser** link to `geo.html`. On vocms0102 the frontend URLs are absolute (`https://vocms0102.cern.ch/cmsShowWeb/…`). On vocms0101 they are relative. |
| `revetor-frontend.pl` | The CGI that starts a session. It reads the `load_file`, `load_file_aaa`, `load_sample` and `load_geo` URL parameters, plus these optional ones: `fwconfig`, `fwgeo`, `simgeo`, `view`, `port`. It builds the `{"action":"load",…}` request, sends it through `RevetorCommon::connect_to_server`, and redirects the browser. The `$REDIR_HOST` check around line 64 must list the host it is deployed on (`vocms0102.cern.ch` here, `vocms0101.cern.ch` on the dev host). Otherwise every load fails with "unconfigured host". |
| `geo.html` | Geometry-only page with no event file. It calls `revetor-frontend.pl?load_geo=1&simgeo=/eos/…&view=…` (geometry browser or overlap table). It needs the `load_geo` and `view` support that is in `revetor-frontend.pl`. |
| `RevetorCommon.pm` | Shared Perl module with `cgi_print`, `cgi_die`, `cgi_end`, `flush`, `recv_with_timeout` and `connect_to_server`. `$RevetorCommon::EVE_HOST` and `$EVE_PORT` (default `localhost:6666`) select the backend. The vocms0101 copy has the same API but differs in formatting and socket handling. |
| `revetor-frontend-inc.pl`, `ui5-gateway-inc.html`, `service-baq.pl` | The earlier generation (July 2026) of the frontend, page and entry script. It has no `view`, `load_geo` or geometry support, and its host check says `vocms0101`. `service-baq.pl` is the previous `service.pl`, kept as a fallback. Not in active use. |
| `revetor-common-frontend.pl` | Older copy of `revetor-frontend-inc.pl` (the only difference: it prints "set new port"). Not deployed. |
| `img/` | Logos and the background picture used by the pages. |

Other entries in `/var/www/html/cmsShowWeb/` are symlinks to scripts kept elsewhere, not in this repo:
`revetor.pl` and `revetor-test.pl` → `~viz/Service/`, `revetor-uni*.cgi` → `~viz/universal-format/`
(VSDNano universal-format service on port 5555), and `revetor-fwdev.pl` → `~fwdev/http-service/` (vocms0101 only).

## Backend ports (vocms0102)

| Port | Service | Environment |
|------|---------|-------------|
| 6666 | cmsShowWebService.exe, CMSSW_17_X and older data | `~viz/Service/env.sh` → `~viz/CMSSW_17_0_0_pre5_cms-fixes-6a745ef` |
| 6669 | cmsShowWebService.exe, CMSSW_20_X (io_v1) data | `~viz/Service/iov1_env.sh` → `~viz/CMSSW_20_1_io_v1_compat` |
| 5555 | serviceVSDNano (universal format) | `~viz/universal-format/runUniversalServ.sh` |

Start these services with `~viz/Service/runservice.sh` (port 6666) and `~viz/Service/runservice.sh iov1` (port 6669).
To stop one, send it `stop_server`, for example `echo '{"action":"stop_server"}' | nc localhost 6669`.

## Deploying

The web directory is owned by root. `revetor-yuxiao.pl` is symlinked from this checkout
(`~viz/Service/FireworksWebService`), and the other files are copies. As root:

```bash
cd /var/www/html/cmsShowWeb
R=/home/viz/Service/FireworksWebService
for f in revetor-frontend.pl RevetorCommon.pm ui5-common-gateway.html geo.html; do
  cmp -s $R/$f $f || { cp -p $f /root/cmsShowWeb-$f-$(date +%F).bak; install -m 644 $R/$f .; }
done
chmod 755 revetor-frontend.pl
cp $R/revetor-yuxiao.pl service.pl && chmod 755 service.pl
```

Keep backups **out of** the web directory, because Apache runs every file there as a CGI (see below).

### SELinux

httpd may read users' home directories (`setsebool -P httpd_read_user_content 1`, already set).
A script that is symlinked from a home directory needs the CGI exec context:

```bash
semanage fcontext -a -t httpd_sys_script_exec_t /some-path/revetor.pl
restorecon -v /some-path/revetor.pl
```

For debugging, run `ausearch -ts recent` and `journalctl -t setroubleshoot --since 21:30`, then `sealert -l <id>`.

## Apache configuration

The whole site is protected by CERN SSO (`AuthType openid-connect`, `Require valid-user`). The
frontend scripts receive the user's identity as `OIDC_CLAIM_cern_upn`.

The relevant part of **vocms0102** `/etc/httpd/conf.d/fireworks.conf`:

```apache
<LocationMatch "^/cmsShowWeb/[^/]+$">
    SetHandler cgi-script
    Options +ExecCGI +FollowSymLinks
    DirectoryIndex revetor.pl ... service.pl
</LocationMatch>
RewriteRule ^/cmsShowWeb/?$  /cmsShowWeb/service.pl  [R,L]
```

This setup runs **every** file in `/cmsShowWeb/` as a CGI, so a static page such as `geo.html` returns a
500 Internal Server Error. To serve the HTML pages as files, add this block after the one above:

```apache
<LocationMatch "^/cmsShowWeb/[^/]+\.html$">
    SetHandler None
</LocationMatch>
```

**vocms0101** runs only `*.pl` files (through `ModPerl::PerlRun`), serves the other files statically,
and denies `*.pm`, `*.swp`, `*~` and `*-before-copy` files.

## Testing without a browser

Run the CGI the same way Apache does, from the web directory:

```bash
cd /var/www/html/cmsShowWeb
SERVER_NAME=vocms0102.cern.ch REQUEST_METHOD=GET OIDC_CLAIM_cern_upn=amraktad \
QUERY_STRING='load_sample=RelValTTBarReco.root&port=6669' ./revetor-frontend.pl
```

The output should include `Connected to port 6669` and either a redirect or the backend's error message.
