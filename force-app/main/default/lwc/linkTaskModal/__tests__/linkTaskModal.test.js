import { createElement } from "lwc";
import LinkTaskModal from "c/linkTaskModal";

function flushPromises() {
  return Promise.resolve().then(() => Promise.resolve());
}

describe("c-link-task-modal", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("open shows dialog and create-mode title in the DOM", async () => {
    const element = createElement("c-link-task-modal", {
      is: LinkTaskModal
    });
    element.recordId = "a0TASK000000001";
    document.body.appendChild(element);
    await flushPromises();

    expect(
      element.shadowRoot.querySelector("section[role='dialog']")
    ).toBeNull();
    element.open();
    await flushPromises();

    expect(
      element.shadowRoot.querySelector("section[role='dialog']")
    ).not.toBeNull();
    const title = element.shadowRoot.querySelector(".slds-modal__title");
    expect(title.textContent.trim()).toBe("Link Task");
  });

  it("modal close control removes dialog from the DOM", async () => {
    const element = createElement("c-link-task-modal", {
      is: LinkTaskModal
    });
    document.body.appendChild(element);
    element.open();
    await flushPromises();

    const closeBtn = element.shadowRoot.querySelector(".slds-modal__close");
    expect(closeBtn).not.toBeNull();
    closeBtn.click();
    await flushPromises();

    expect(
      element.shadowRoot.querySelector("section[role='dialog']")
    ).toBeNull();
  });
});
