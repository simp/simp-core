#!/usr/bin/env python3
"""HTTPS kickstart and yum server for testing SIMP kickstarts.

Serves a SIMP kickstart directory under /ks/ and emulates a SIMP yum server's
layout (see repodetect.sh) under /yum/ by redirecting to public mirrors:

  /yum/<dist>/<ver>/<arch>/.treeinfo        DVD-style .treeinfo built from the
                                            mirror's BaseOS .treeinfo
  /yum/<dist>/<ver>/<arch>/{images,BaseOS,AppStream}/...
  /yum/SIMP/<dist>/<ver>/<arch>/{CRB,PowerTools,epel,openvox}/...
  /yum/SIMP/<dist>/<ver>/<arch>/SIMP/...    only with --simp-repo-url

Placeholders (#NAME#) in *.cfg files are replaced with --set NAME=VALUE.
"""

import argparse
import configparser
import io
import os
import re
import ssl
import sys
import urllib.parse
import urllib.request
from functools import lru_cache
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

OS_MIRROR = 'https://repo.almalinux.org/almalinux'
EPEL_MIRROR = 'https://dl.fedoraproject.org/pub/epel'
OPENVOX_MIRROR = 'https://yum.voxpupuli.org'

YUM_RE = re.compile(r'^/yum/(?P<dist>[^/]+)/(?P<ver>[0-9]+)/(?P<arch>[^/]+)(?P<rest>/.*)?$')
SIMP_RE = re.compile(r'^/yum/SIMP/(?P<dist>[^/]+)/(?P<ver>[0-9]+)/(?P<arch>[^/]+)/(?P<repo>[^/]+)(?P<rest>/.*)?$')


@lru_cache(maxsize=None)
def dvd_treeinfo(ver, arch):
    """Return a .treeinfo for a DVD-style tree with BaseOS/ and AppStream/."""
    url = f'{OS_MIRROR}/{ver}/BaseOS/{arch}/os/.treeinfo'
    with urllib.request.urlopen(url, timeout=60) as resp:
        text = resp.read().decode()

    ti = configparser.ConfigParser(interpolation=None)
    ti.optionxform = str
    ti.read_string(text)

    for section in ti.sections():
        if not section.startswith('variant-'):
            continue
        variant = ti[section]['id']
        ti[section]['repository'] = variant
        ti[section]['packages'] = f'{variant}/Packages'

    if ti.has_section('general'):
        ti['general']['repository'] = 'BaseOS'
        ti['general']['packagedir'] = 'BaseOS/Packages'

    out = io.StringIO()
    ti.write(out)
    return out.getvalue().encode()


class Handler(BaseHTTPRequestHandler):
    server_version = 'SIMPKickstartTest/1.0'

    def log_message(self, fmt, *args):
        sys.stdout.write('%s %s\n' % (self.address_string(), fmt % args))
        sys.stdout.flush()

    def do_HEAD(self):
        self.handle_request(head=True)

    def do_GET(self):
        self.handle_request(head=False)

    def send_body(self, body, content_type='application/octet-stream', head=False):
        self.send_response(200)
        self.send_header('Content-Type', content_type)
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        if not head:
            self.wfile.write(body)

    def redirect(self, url):
        self.send_response(302)
        self.send_header('Location', url)
        self.send_header('Content-Length', '0')
        self.end_headers()

    def handle_request(self, head):
        path = urllib.parse.unquote(self.path.split('?', 1)[0])
        cfg = self.server.cfg

        if path.startswith('/ks/'):
            return self.serve_ks(path[len('/ks/'):], head)

        m = SIMP_RE.match(path)
        if m:
            ver, arch, repo, rest = m['ver'], m['arch'], m['repo'], m['rest'] or '/'
            if repo in ('CRB', 'PowerTools'):
                return self.redirect(f'{OS_MIRROR}/{ver}/{repo}/{arch}/os{rest}')
            if repo == 'epel':
                return self.redirect(f'{EPEL_MIRROR}/{ver}/Everything/{arch}{rest}')
            if repo == 'openvox':
                return self.redirect(f'{OPENVOX_MIRROR}/{cfg.openvox}/el/{ver}/{arch}{rest}')
            if repo == 'SIMP' and cfg.simp_repo_url:
                return self.redirect(cfg.simp_repo_url.rstrip('/') + rest)
            return self.send_error(404)

        m = YUM_RE.match(path)
        if m:
            ver, arch, rest = m['ver'], m['arch'], m['rest'] or '/'
            if rest == '/.treeinfo':
                return self.send_body(dvd_treeinfo(ver, arch), 'text/plain', head)
            for repo in ('BaseOS', 'AppStream'):
                if rest.startswith(f'/{repo}/'):
                    return self.redirect(f'{OS_MIRROR}/{ver}/{repo}/{arch}/os{rest[len(repo) + 1:]}')
            if rest.startswith('/images/'):
                return self.redirect(f'{OS_MIRROR}/{ver}/BaseOS/{arch}/os{rest}')
            return self.send_error(404)

        return self.send_error(404)

    def serve_ks(self, name, head):
        cfg = self.server.cfg
        if not name or '/' in name or name.startswith('.'):
            return self.send_error(404)

        for directory in (cfg.ks_dir, cfg.extra_dir):
            if not directory:
                continue
            path = os.path.join(directory, name)
            if os.path.isfile(path):
                break
        else:
            return self.send_error(404)

        with open(path, 'rb') as fh:
            body = fh.read()

        if name.endswith('.cfg'):
            text = body.decode()
            for key, value in cfg.set:
                text = text.replace(f'#{key}#', value)
            leftover = sorted(set(re.findall(r'#[A-Z]+#', text)))
            if leftover:
                self.log_message('WARNING: unreplaced placeholders in %s: %s', name, ' '.join(leftover))
            body = text.encode()

        return self.send_body(body, 'text/plain', head)


def parse_set(value):
    key, sep, val = value.partition('=')
    if not sep or not key:
        raise argparse.ArgumentTypeError(f"expected NAME=VALUE, got '{value}'")
    return (key, val)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--listen', default='0.0.0.0')
    parser.add_argument('--port', type=int, default=8443)
    parser.add_argument('--cert', required=True)
    parser.add_argument('--key', required=True)
    parser.add_argument('--ks-dir', required=True, help='kickstart directory to serve under /ks/')
    parser.add_argument('--extra-dir', help='additional files to serve under /ks/')
    parser.add_argument('--openvox', default='openvox9', help='OpenVox collection (default: openvox9)')
    parser.add_argument('--simp-repo-url', help='SIMP repository to serve as the SIMP repo')
    parser.add_argument('--set', type=parse_set, action='append', default=[], metavar='NAME=VALUE',
                        help='replace #NAME# in *.cfg files')
    cfg = parser.parse_args()

    httpd = ThreadingHTTPServer((cfg.listen, cfg.port), Handler)
    httpd.cfg = cfg
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    ctx.load_cert_chain(cfg.cert, cfg.key)
    httpd.socket = ctx.wrap_socket(httpd.socket, server_side=True)

    print(f'Serving {cfg.ks_dir} on https://{cfg.listen}:{cfg.port}/', flush=True)
    httpd.serve_forever()


if __name__ == '__main__':
    main()
