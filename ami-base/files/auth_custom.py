

def process_token(response, token, userinfo):
    """
    This is default implementation of token check.
    You can just drop your own implementation and replace this
    file. Don't forget to send response and body of some sort.
    At this point token is validated and decoded.
    """
    response.send_response(200)
    response.send_header("Content-type", "text/javascript")
    user = userinfo["username"].split("@")[0]
    response.send_header("A-User", user)
    response.send_header("A-Email", userinfo["email"])
    response.send_header("A-Name", userinfo["name"])
    response.end_headers()
    response.wfile.write("{\"hello\":\"world\"}".encode())
