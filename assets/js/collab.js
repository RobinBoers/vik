import { EditorView, ViewPlugin, ViewUpdate } from "@codemirror/view";
import { Text, ChangeSet } from "@codemirror/state";

import {
  Update,
  receiveUpdates,
  sendableUpdates,
  collab,
  getSyncedVersion,
} from "@codemirror/collab";

function pushUpdates(lv, version, fullUpdates) {
  // Strip off transaction data
  const updates = fullUpdates.map((u) => ({
    clientID: u.clientID,
    changes: u.changes.toJSON(),
    effects: u.effects,
  }));

  return new Promise((resolve) => {
    // lv.pushEvent("collab-updates", {})
    // socket.emit("pushUpdates", version, );
    // socket.once("pushUpdateResponse", resolve);
  });
}
