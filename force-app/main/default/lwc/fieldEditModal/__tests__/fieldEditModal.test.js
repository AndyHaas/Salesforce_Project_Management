import { createElement } from "lwc";
import FieldEditModal from "c/fieldEditModal";

function flushPromises() {
  return Promise.resolve().then(() => Promise.resolve());
}

function teardown() {
  while (document.body.firstChild) {
    document.body.removeChild(document.body.firstChild);
  }
}

describe("c-field-edit-modal", () => {
  afterEach(teardown);

  it("renders modal dialog shell", async () => {
    const el = createElement("c-field-edit-modal", { is: FieldEditModal });
    document.body.appendChild(el);
    await flushPromises();

    const dialog = el.shadowRoot.querySelector('section[role="dialog"]');
    expect(dialog).not.toBeNull();
  });

  it("open() shows field label in header", async () => {
    const el = createElement("c-field-edit-modal", { is: FieldEditModal });
    document.body.appendChild(el);
    el.open("001xxx", "Status__c", "Status", "Open", "STRING", []);
    await flushPromises();

    const title = el.shadowRoot.querySelector(".slds-modal__title");
    expect(title.textContent).toContain("Status");
  });
});
