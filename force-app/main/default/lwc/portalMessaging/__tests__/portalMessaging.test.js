import { createElement } from "lwc";
import PortalMessaging from "c/portalMessaging";

jest.mock("c/portalMessageComposeModal", () => ({
  __esModule: true,
  default: {
    open: jest.fn().mockResolvedValue(undefined)
  }
}));

function flushPromises() {
  return Promise.resolve().then(() => Promise.resolve());
}

function teardown() {
  while (document.body.firstChild) {
    document.body.removeChild(document.body.firstChild);
  }
}

describe("c-portal-messaging", () => {
  afterEach(teardown);

  it("renders messaging shell (lightning-card)", async () => {
    const el = createElement("c-portal-messaging", { is: PortalMessaging });
    el.recordId = "001000000000000AAA";
    document.body.appendChild(el);
    await flushPromises();
    await flushPromises();

    const card = el.shadowRoot.querySelector("lightning-card.messaging-card");
    expect(card).not.toBeNull();
  });
});
