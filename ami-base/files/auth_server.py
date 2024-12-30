from http.server import BaseHTTPRequestHandler, HTTPServer
import logging
import jwt
import requests
import os
import json
import auth_custom

cache = {}
jwks_client = None

def init_data():
    global jwks_client
    region = os.environ['Region']
    pool_id = os.environ['AuthUserPoolId']
    jwks_uri = f"https://cognito-idp.{region}.amazonaws.com/{pool_id}/.well-known/jwks.json"
    logging.info(f"Fetching JWKS from url {jwks_uri}")
    jwks_client = jwt.PyJWKClient(jwks_uri)

class S(BaseHTTPRequestHandler):
  
    def get_proxies(self):
        proxiesDict = {}
        if "https_proxy" in os.environ:
            proxiesDict = {"https": os.environ["https_proxy"]}
        return proxiesDict
    
    def __init__(self, *args, **kwargs):
        logging.info("Initializing handler")
      
        BaseHTTPRequestHandler.__init__(self, *args, **kwargs)
      

    def respond(self):
        token = self.headers['X-Amzn-Oidc-Accesstoken']
          
        userinfo = {}
        if token not in cache:
          logging.info("Fetching userinfo")
          url = 'https://' + os.environ['AuthUserPoolDomain'] +'/oauth2/userInfo'
          headers = {'Authorization': 'Bearer ' + token}
          r = requests.get(url, headers=headers, proxies=self.get_proxies())
          userinfo = r.json()
          if "error" not in userinfo:
            cache[token] = userinfo
          else:
            self.send_response(401)
            self.end_headers()
            self.wfile.write(json.dumps(userinfo).encode())
            return

        userinfo = cache[token]
        
        public_key = jwks_client.get_signing_key_from_jwt(token)
        token = jwt.decode(token.encode(), public_key, algorithms=["RS256"])
        auth_custom.process_token(self, token, userinfo)

    def do_GET(self):
       self.respond()

    def do_HEAD(self):
       self.respond()

    def do_PUT(self):
       self.respond()

    def do_POST(self):
       self.respond()


    def do_PUT(self):
       self.respond()

    def do_DELETE(self):
       self.respond()

    def do_OPTIONS(self):
       self.respond()


def run(server_class=HTTPServer, handler_class=S, port=8081):
    logging.basicConfig(level=logging.INFO)
    server_address = ('', port)
    httpd = server_class(server_address, handler_class)
  
    init_data()
    logging.info('Starting httpd...\n')
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    httpd.server_close()
    logging.info('Stopping httpd...\n')

if __name__ == '__main__':
    from sys import argv

    if len(argv) == 2:
        run(port=int(argv[1]))
    else:
        run()

