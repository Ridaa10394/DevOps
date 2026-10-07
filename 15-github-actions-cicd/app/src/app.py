"""Session 16 demo app: a small Flask API that the CI/CD pipeline builds, tests and deploys."""
import os
import platform

from flask import Flask, jsonify, request

from src.calculator import OPERATIONS

APP_VERSION = os.environ.get("APP_VERSION", "dev")


def create_app():
    app = Flask(__name__)

    @app.get("/")
    def index():
        return jsonify(
            app="devops-s16-app",
            message="Hello from the Session 16 CI/CD pipeline",
            version=APP_VERSION,
            endpoints=["/", "/health", "/calc/<op>?a=&b="],
        )

    @app.get("/health")
    def health():
        return jsonify(status="ok", version=APP_VERSION, python=platform.python_version())

    @app.get("/calc/<op>")
    def calc(op):
        func = OPERATIONS.get(op)
        if func is None:
            return jsonify(error=f"unknown operation '{op}'"), 404
        try:
            a = float(request.args["a"])
            b = float(request.args["b"])
        except (KeyError, ValueError):
            return jsonify(error="query params a and b must be numbers"), 400
        try:
            result = func(a, b)
        except ValueError as exc:
            return jsonify(error=str(exc)), 400
        return jsonify(op=op, a=a, b=b, result=result)

    return app


app = create_app()

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", "5000")))
