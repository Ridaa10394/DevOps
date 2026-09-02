from flask import Flask
import os

app = Flask(__name__)
PORT = int(os.environ.get("PORT", 5000))


@app.route("/")
def hello():
    return f"""
    <html>
      <head><title>Python Hello World</title></head>
      <body style="font-family: sans-serif; text-align: center; padding-top: 80px;">
        <h1>Hello World from Python</h1>
        <p>Served by Flask inside a Docker container on port {PORT}</p>
      </body>
    </html>
    """


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=PORT)
