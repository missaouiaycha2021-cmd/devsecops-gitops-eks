from flask import Flask, jsonify

app = Flask(__name__)
VERSION = "1.0"


@app.route("/")
def index():
    return "<h1>Bienvenue</h1>"


@app.route("/health")
def health():
    return jsonify(status="ok")


@app.route("/version")
def version():
    return jsonify(version=VERSION)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
