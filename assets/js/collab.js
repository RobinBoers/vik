import { ViewPlugin } from "@codemirror/view";
import { ChangeSet } from "@codemirror/state";

import {
  receiveUpdates,
  sendableUpdates,
  collab,
  getSyncedVersion,
} from "@codemirror/collab";

function pushEventAsync(lv, event, payload) {
  return new Promise((resolve) => {
    lv.pushEvent(event, payload, resolve);
  });
}

function handleEventAsync(lv, event) {
  return new Promise((resolve) => {
    lv.handleEvent(event, resolve);
  });
}

function getDocument(lv) {
  return pushEventAsync(lv, "collab:doc");
}

function pushUpdates(lv, version, fullUpdates) {
  // Strip off transaction data
  const updates = fullUpdates.map((u) => ({
    clientID: u.clientID,
    changes: u.changes.toJSON(),
    effects: u.effects,
  }));

  return pushEventAsync(lv, "collab:push", { version, updates });
}

function fetchUpdates(lv, version) {
  return pushEventAsync(lv, "collab:fetch", { version }).then((updates) =>
    updates.map((u) => ({
      changes: ChangeSet.fromJSON(u.changes),
      clientID: u.clientID,
    }))
  );
}

function pullUpdates(lv) {
  return handleEventAsync(lv, "collab:pull").then((updates) => 
    updates.map((u) => ({
      changes: ChangeSet.fromJSON(u.changes),
      clientID: u.clientID,
    }))
  );
}

function peerExtension(lv, startVersion) {
  let plugin = ViewPlugin.fromClass(class {
    constructor(view) {
      this.view = view;
      this.pushing = false;
      this.done = false;
      this.fetch();
      this.pull();
    }

    update(update) {
      if (update.docChanged) this.push()
    }

    async push() {
      let updates = sendableUpdates(this.view.state)
      if (this.pushing || !updates.length) return
      this.pushing = true
      let version = getSyncedVersion(this.view.state)
      await pushUpdates(lv, version, updates)
      this.pushing = false
      // Regardless of whether the push failed or new updates came in
      // while it was running, try again if there's updates remaining
      if (sendableUpdates(this.view.state).length)
        setTimeout(() => this.push(), 100)
    }

    async fetch() {
      if(!this.done) {
        let updates = await fetchUpdates(lv, version)
        this.view.dispatch(receiveUpdates(this.view.state, updates))

        // Every 10 seconds, try to fetch any updates missed since
        // the last pull.
        setTimeout(() => this.fetch, 10_000);
      }
    }

    async pull() {
      while (!this.done) {
        let updates = await pullUpdates(lv)
        this.view.dispatch(receiveUpdates(this.view.state, updates))
      }
    }

    destroy() { this.done = true }
  })

  return [collab({startVersion}), plugin]
}

export async function createPeer(lv) {
  let { version, updates, doc } = await getDocument(lv);
  for (let update of updates) doc = applyUpdate(doc, update);

  return { doc, collab: peerExtension(lv, version) };
}
