import { createElement } from "lwc";
import PortalFileAttachments from "c/portalFileAttachments";

function flushPromises() {
  return Promise.resolve().then(() => Promise.resolve());
}

function teardown() {
  while (document.body.firstChild) {
    document.body.removeChild(document.body.firstChild);
  }
}

describe("c-portal-file-attachments", () => {
  afterEach(teardown);

  it("mounts without error", async () => {
    const el = createElement("c-portal-file-attachments", {
      is: PortalFileAttachments
    });
    document.body.appendChild(el);
    await flushPromises();

    expect(el.shadowRoot).not.toBeNull();
  });
});
