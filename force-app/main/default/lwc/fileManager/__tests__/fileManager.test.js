import { createElement } from "lwc";
import FileManager from "c/fileManager";

function flushPromises() {
  return Promise.resolve().then(() => Promise.resolve());
}

function teardown() {
  while (document.body.firstChild) {
    document.body.removeChild(document.body.firstChild);
  }
}

describe("c-file-manager", () => {
  afterEach(teardown);

  it("list variant renders nested file attachments for supplied rows", async () => {
    const el = createElement("c-file-manager", { is: FileManager });
    el.variant = "list";
    el.fileRows = [
      {
        contentDocumentId: "069000000000000AAA",
        contentVersionId: "068000000000000AAA",
        title: "Spec",
        fileExtension: "pdf"
      }
    ];
    document.body.appendChild(el);
    await flushPromises();

    const inner = el.shadowRoot.querySelector("c-portal-file-attachments");
    expect(inner).not.toBeNull();
  });

  it("composer variant exposes empty upload ids until files are added", async () => {
    const el = createElement("c-file-manager", { is: FileManager });
    el.variant = "composer";
    el.recordId = "a00000000000000AAA";
    document.body.appendChild(el);
    await flushPromises();

    expect(el.getUploadedContentVersionIds()).toEqual([]);
    el.resetComposerState();
    expect(el.getUploadedContentVersionIds()).toEqual([]);
  });
});
