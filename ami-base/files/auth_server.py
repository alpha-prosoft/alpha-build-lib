from http.server import BaseHTTPRequestHandler, HTTPServer
import logging
import jwt
import requests
import os
import json
import auth_custom

cache = {}

class S(BaseHTTPRequestHandler):


    def respond(self):
        header = self.headers['X-Amzn-Oidc-Accesstoken']
          
        userinfo = {}
        if header not in cache:
          logging.info("Fetching userinfo")
          url = 'https://' + os.environ['AuthUserPoolDomain'] +'/oauth2/userInfo'
          headers = {'Authorization': 'Bearer ' + header}
          r = requests.get(url, headers=headers)
          userinfo = r.json()
          if "error" not in userinfo:
            cache[header] = userinfo
          else:
            self.send_response(401)
            self.end_headers()
            self.wfile.write(json.dumps(userinfo).encode())
            return

        userinfo = cache[header]
        token = jwt.decode(header.encode(), verify=False)
        auth_custom.process_token(self, token)


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

