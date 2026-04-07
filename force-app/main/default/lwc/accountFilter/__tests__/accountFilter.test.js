import { createElement } from "lwc";
import AccountFilter from "c/accountFilter";

function flushPromises() {
  return Promise.resolve().then(() => Promise.resolve());
}

describe("c-account-filter", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("renders without throwing when mounted", async () => {
    const element = createElement("c-account-filter", {
      is: AccountFilter
    });
    document.body.appendChild(element);
    await flushPromises();

    expect(element.shadowRoot).not.toBeNull();
  });
});
