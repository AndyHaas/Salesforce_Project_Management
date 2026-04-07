import { createElement } from "lwc";
import SalesforceMessaging from "c/salesforceMessaging";

function flushPromises() {
  return Promise.resolve().then(() => Promise.resolve());
}

function teardown() {
  while (document.body.firstChild) {
    document.body.removeChild(document.body.firstChild);
  }
}

describe("c-salesforce-messaging", () => {
  afterEach(teardown);

  it("delegates to nested portal messaging component", async () => {
    const el = createElement("c-salesforce-messaging", {
      is: SalesforceMessaging
    });
    el.recordId = "001000000000000AAA";
    document.body.appendChild(el);
    await flushPromises();
    await flushPromises();

    const inner = el.shadowRoot.querySelector("c-portal-messaging");
    expect(inner).not.toBeNull();
  });
});
