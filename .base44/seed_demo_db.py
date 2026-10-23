#!/usr/bin/env python3
"""Populate the dashboard's master database for the sandbox preview.

The workflow dashboard lists workflows from the user's master database
(``~/.pegasus/workflow.db``), which is normally created by running workflows
with Pegasus. Running real workflows needs a full Pegasus + HTCondor install,
so for the preview we seed the master database from the master database that
ships with the pegasus-python test resources (five archived hello-world
workflows) and point each workflow's ``db_url`` at that same file, so the home
page, workflow detail and job pages all render.

Idempotent: an existing master database is never modified.
"""

import os
import shutil
import sqlite3

FIXTURE = (
    "/pegasus/packages/pegasus-python/test/resources/"
    "monitoring-db/monitoring-rest-api-master.db"
)
MASTER_DB = os.path.join(os.path.expanduser("~"), ".pegasus", "workflow.db")


def main():
    if os.environ.get("BASE44_PREVIEW_MODE") != "1":
        print("BASE44_PREVIEW_MODE is not 1: not seeding demo data")
        return

    if os.path.exists(MASTER_DB):
        print("Master database already exists, leaving it untouched: %s" % MASTER_DB)
        return

    os.makedirs(os.path.dirname(MASTER_DB), exist_ok=True)
    shutil.copyfile(FIXTURE, MASTER_DB)

    db_url = "sqlite:///" + MASTER_DB
    with sqlite3.connect(MASTER_DB) as connection:
        connection.execute("UPDATE master_workflow SET db_url = ?", (db_url,))
        connection.execute("UPDATE workflow SET db_url = ?", (db_url,))

    print("Seeded demo workflows into %s from %s" % (MASTER_DB, FIXTURE))


if __name__ == "__main__":
    main()
