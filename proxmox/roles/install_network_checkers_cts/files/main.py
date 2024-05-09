import os
from fastapi import FastAPI
import requests

app = FastAPI()


def _get_urls_list(env_var_name):
    variable = os.getenv(env_var_name, "")
    if len(variable) > 0:
        return variable.split(";")
    else:
        return []


REACHABLE_URLS = _get_urls_list("REACHABLE_URLS")
UNREACHABLE_URLS = _get_urls_list("UNREACHABLE_URLS")


@app.get("/healthcheck")
def read_root():
    return {"status": True}


def _try_reach(url, should_timeout):
    try:
        requests.get(f"{url}/healthcheck", timeout=2, verify=False)
        return {"url": url, "status": not should_timeout, "shouldTimeout": should_timeout}
    except requests.exceptions.Timeout as e:
        print(f"Timed out: {url}")
        return {"url": url, "status": should_timeout, "shouldTimeout": should_timeout, "message": f"{e}"}
    except BaseException as e:
        print(e.__str__())
        return {"url": url, "status": should_timeout, "shouldTimeout": should_timeout, "message": f"{e}"}


def _can_reach_all_reachable():
    statuses = [_try_reach(url, should_timeout=False) for url in REACHABLE_URLS]
    return statuses


def _cannot_reach_all_unreachable():
    statuses = [_try_reach(url, should_timeout=True) for url in UNREACHABLE_URLS]
    return statuses


@app.get("/networkcheck")
def read_item():
    statuses = _cannot_reach_all_unreachable() + _can_reach_all_reachable()
    and_status = all(status["status"] for status in statuses)
    return {"status": and_status, "details": statuses}
