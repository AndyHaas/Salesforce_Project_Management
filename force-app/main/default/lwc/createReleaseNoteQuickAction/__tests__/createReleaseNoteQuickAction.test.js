import { createElement } from "lwc";
import CreateReleaseNoteQuickAction from "c/createReleaseNoteQuickAction";

function flushPromises() {
  return Promise.resolve().then(() => Promise.resolve());
}

function collectShadowDeep(root, selector) {
  const out = [];
  root.querySelectorAll(selector).forEach((el) => out.push(el));
  root.querySelectorAll("*").forEach((node) => {
    if (node.shadowRoot) {
      out.push(...collectShadowDeep(node.shadowRoot, selector));
    }
  });
  return out;
}

describe("c-create-release-note-quick-action", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("dispatches CloseActionScreenEvent when Cancel is clicked", async () => {
    const element = createElement("c-create-release-note-quick-action", {
      is: CreateReleaseNoteQuickAction
    });
    document.body.appendChild(element);
    await flushPromises();

    const dispatchSpy = jest.spyOn(element, "dispatchEvent");
    const buttons = collectShadowDeep(element.shadowRoot, "lightning-button");
    const cancelButton = buttons.find((b) => b.label === "Cancel");
    expect(cancelButton).toBeDefined();
    cancelButton.click();
    await flushPromises();

    const closeEvent = dispatchSpy.mock.calls
      .map((c) => c[0])
      .find((e) => e && typeof e.type === "string" && e.type.includes("close"));
    expect(closeEvent).toBeDefined();
    expect(closeEvent.type).toBe("lightning__actionsclosescreen");
  });
});
