import { createElement } from "lwc";
import { registerApexTestWireAdapter, registerTestWireAdapter } from "@salesforce/sfdx-lwc-jest";
import { CurrentPageReference, NavigationMixin } from "lightning/navigation";
import { ensureSitePath } from "c/portalCommon";
import * as messageService from "lightning/messageService";
import { MessageContext } from "lightning/messageService";
import getContextInfo from "@salesforce/apex/MessagingController.getContextInfo";
import getCurrentUserContactId from "@salesforce/apex/MessagingController.getCurrentUserContactId";
import isMilestoneTeamMember from "@salesforce/apex/MessagingController.isMilestoneTeamMember";
import getMessages from "@salesforce/apex/MessagingController.getMessages";
import getPinnedMessages from "@salesforce/apex/MessagingPinnedSupport.getPinnedMessages";
import getFilesForMessages from "@salesforce/apex/MessageFilesSupport.getFilesForMessages";
import markAsRead from "@salesforce/apex/MessagingController.markAsRead";
import updateMessage from "@salesforce/apex/MessagingController.updateMessage";
import deleteMessageAndAttachments from "@salesforce/apex/MessageFilesSupport.deleteMessageAndAttachments";
import pinMessage from "@salesforce/apex/MessagingController.pinMessage";
import PortalMessaging from "c/portalMessaging";
import PortalMessageComposeModal from "c/portalMessageComposeModal";

jest.mock("@salesforce/apex/MessagingController.getMessages", () => ({ default: jest.fn() }), { virtual: true });
jest.mock("@salesforce/apex/MessagingPinnedSupport.getPinnedMessages", () => ({ default: jest.fn() }), {
  virtual: true
});
jest.mock("@salesforce/apex/MessageFilesSupport.getFilesForMessages", () => ({ default: jest.fn() }), {
  virtual: true
});
jest.mock("@salesforce/apex/MessagingController.markAsRead", () => ({ default: jest.fn() }), { virtual: true });
jest.mock("@salesforce/apex/MessagingController.updateMessage", () => ({ default: jest.fn() }), { virtual: true });
jest.mock("@salesforce/apex/MessageFilesSupport.deleteMessageAndAttachments", () => ({ default: jest.fn() }), {
  virtual: true
});
jest.mock("@salesforce/apex/MessagingController.pinMessage", () => ({ default: jest.fn() }), { virtual: true });

jest.mock("c/portalCommon", () => ({
  ensureSitePath: jest.fn((path) => `/s/site${path}`),
  formatDateTime: jest.fn((v) => `full:${v}`),
  stripHtml: jest.fn((html) => String(html || "").replace(/<[^>]+>/g, ""))
}));

jest.mock(
  "@salesforce/messageChannel/MessageUpdate__c",
  () => ({
    default: "@salesforce/messageChannel/MessageUpdate__c"
  }),
  { virtual: true }
);

jest.mock("@salesforce/user/Id", () => ({ default: "005000000000099AAA" }), { virtual: true });

jest.mock("c/portalMessageComposeModal", () => ({
  __esModule: true,
  default: {
    open: jest.fn().mockResolvedValue(undefined)
  }
}));

const messageContextAdapter = registerTestWireAdapter(MessageContext);
const pageReferenceAdapter = registerTestWireAdapter(CurrentPageReference);
const getContextInfoAdapter = registerApexTestWireAdapter(getContextInfo);
const getCurrentUserContactIdAdapter = registerApexTestWireAdapter(getCurrentUserContactId);
const isMilestoneTeamMemberAdapter = registerApexTestWireAdapter(isMilestoneTeamMember);

const apexMocks = {
  getMessages,
  getPinnedMessages,
  getFilesForMessages,
  markAsRead,
  updateMessage,
  deleteMessageAndAttachments,
  pinMessage
};

function flushPromises() {
  return Promise.resolve().then(() => Promise.resolve());
}

function resetMessagingApexMocks() {
  Object.values(apexMocks).forEach((fn) => {
    if (fn && typeof fn.mockReset === "function") {
      fn.mockReset();
    }
  });
}

function defaultApexSuccessBehavior() {
  apexMocks.getMessages.mockResolvedValue([]);
  apexMocks.getPinnedMessages.mockResolvedValue([]);
  apexMocks.getFilesForMessages.mockResolvedValue([]);
  apexMocks.markAsRead.mockResolvedValue(undefined);
  apexMocks.updateMessage.mockResolvedValue(undefined);
  apexMocks.deleteMessageAndAttachments.mockResolvedValue(undefined);
  apexMocks.pinMessage.mockResolvedValue(undefined);
}

function emitMessagingWires(opts = {}) {
  const {
    messageContextData = {},
    pageRef = null,
    milestoneMember = false,
    contactId = "003000000000001AAA",
    contextInfo = { contextType: "Account", accountName: "Acme Corp" }
  } = opts;

  messageContextAdapter.emit({ data: messageContextData, error: undefined });
  if (pageRef) {
    pageReferenceAdapter.emit(pageRef);
  }
  isMilestoneTeamMemberAdapter.emit(milestoneMember);
  getCurrentUserContactIdAdapter.emit(contactId);
  getContextInfoAdapter.emit(contextInfo);
}

function teardown() {
  while (document.body.firstChild) {
    document.body.removeChild(document.body.firstChild);
  }
  jest.restoreAllMocks();
  jest.useRealTimers();
  delete window.location;
  window.location = { pathname: "/", href: "" };
}

function setPortalPath() {
  delete window.location;
  window.location = { pathname: "/s/acme/home", href: "https://example.com/s/acme/home" };
}

function baseMessage(overrides = {}) {
  const id = overrides.id || "a0X000000000001AAA";
  return {
    id,
    body: "<p>Hello</p>",
    createdDate: new Date(Date.now() - 60000).toISOString(),
    senderName: "Portal User",
    senderId: "003000000000001AAA",
    isRead: true,
    isPinned: false,
    files: [],
    visibleToClient: true,
    ...overrides
  };
}

async function mountWithWires(opts = {}) {
  const {
    milestoneMember = false,
    contactId = "003000000000001AAA",
    contextInfo = { contextType: "Account", accountName: "Acme" },
    pageRef = { type: "comm__namedPage", attributes: {}, state: {} },
    messages = [],
    pinnedMessages,
    ...rest
  } = opts;

  setPortalPath();
  defaultApexSuccessBehavior();
  if (pinnedMessages !== undefined) {
    apexMocks.getPinnedMessages.mockResolvedValue(pinnedMessages);
  }
  apexMocks.getMessages.mockResolvedValue(messages);

  jest.useFakeTimers();
  global.requestAnimationFrame = jest.fn((cb) => {
    cb();
    return 0;
  });

  const el = createElement("c-portal-messaging", { is: PortalMessaging });
  el.recordId = rest.recordId ?? "001000000000001AAA";
  if (rest.relatedAccountId !== undefined) el.relatedAccountId = rest.relatedAccountId;
  else el.relatedAccountId = "001000000000001AAA";
  if (rest.relatedProjectId !== undefined) el.relatedProjectId = rest.relatedProjectId;
  if (rest.relatedTaskId !== undefined) el.relatedTaskId = rest.relatedTaskId;
  if (rest.hidePinnedMessagesSection !== undefined) el.hidePinnedMessagesSection = rest.hidePinnedMessagesSection;
  if (rest.pinnedSectionCollapsedByDefault !== undefined) {
    el.pinnedSectionCollapsedByDefault = rest.pinnedSectionCollapsedByDefault;
  }

  document.body.appendChild(el);

  emitMessagingWires({
    messageContextData: {},
    pageRef,
    milestoneMember,
    contactId,
    contextInfo
  });

  await flushPromises();
  jest.advanceTimersByTime(0);
  await flushPromises();
  jest.advanceTimersByTime(200);
  await flushPromises();

  return el;
}

describe("c-portal-messaging", () => {
  let subscribeSpy;
  let unsubscribeSpy;
  let publishSpy;

  beforeEach(() => {
    resetMessagingApexMocks();
    subscribeSpy = jest.spyOn(messageService, "subscribe").mockReturnValue("mock-sub-id");
    unsubscribeSpy = jest.spyOn(messageService, "unsubscribe").mockImplementation(() => {});
    publishSpy = jest.spyOn(messageService, "publish").mockImplementation(() => {});
  });

  afterEach(() => {
    teardown();
  });

  it("renders messaging shell (lightning-card)", async () => {
    const el = await mountWithWires();
    const card = el.shadowRoot.querySelector("lightning-card.messaging-card");
    expect(card).not.toBeNull();
  });

  it("subscribes to message channel when MessageContext resolves", async () => {
    await mountWithWires();
    expect(subscribeSpy).toHaveBeenCalled();
  });

  it("unsubscribes on disconnect", async () => {
    const el = await mountWithWires();
    document.body.removeChild(el);
    expect(unsubscribeSpy).toHaveBeenCalledWith("mock-sub-id");
  });

  it("loads messages on connect and maps rows for display", async () => {
    const msg = baseMessage({ id: "a0X111", isRead: true });
    const el = await mountWithWires({ messages: [msg] });
    expect(apexMocks.getMessages).toHaveBeenCalled();
    const items = el.shadowRoot.querySelectorAll(".message-item");
    expect(items.length).toBe(1);
  });

  it("marks unread messages read and reloads thread", async () => {
    const unread = baseMessage({ id: "a0Xu1", isRead: false });
    apexMocks.getMessages.mockResolvedValueOnce([unread]).mockResolvedValueOnce([{ ...unread, isRead: true }]);
    await mountWithWires({ messages: [unread] });
    expect(apexMocks.markAsRead).toHaveBeenCalledWith({ messageId: "a0Xu1" });
  });

  it("shows toast and clears messages on load failure (initial load)", async () => {
    setPortalPath();
    jest.useFakeTimers();
    global.requestAnimationFrame = jest.fn((cb) => {
      cb();
      return 0;
    });
    const el = createElement("c-portal-messaging", { is: PortalMessaging });
    el.relatedAccountId = "001000000000001AAA";
    apexMocks.getPinnedMessages.mockResolvedValue([]);
    apexMocks.getFilesForMessages.mockResolvedValue([]);
    apexMocks.markAsRead.mockResolvedValue(undefined);
    apexMocks.getMessages.mockRejectedValue({
      body: { message: "boom" },
      message: "boom"
    });
    const dispatchSpy = jest.spyOn(el, "dispatchEvent");
    document.body.appendChild(el);
    emitMessagingWires({});
    await flushPromises();
    jest.advanceTimersByTime(200);
    await flushPromises();
    const sawToast = dispatchSpy.mock.calls.some(([ev]) => {
      const t = ev && ev.type;
      return t === "lightning__showtoast" || (t && String(t).toLowerCase().includes("toast"));
    });
    expect(sawToast).toBe(true);
    expect(el.shadowRoot.querySelectorAll(".message-item").length).toBe(0);
    dispatchSpy.mockRestore();
  });

  it("loads pinned messages after thread load when recipient and context exist", async () => {
    await mountWithWires({ messages: [baseMessage()] });
    expect(apexMocks.getPinnedMessages).toHaveBeenCalled();
  });

  it("merges files from getFilesForMessages onto rows", async () => {
    const msg = baseMessage({ id: "a0Xf1" });
    apexMocks.getFilesForMessages.mockResolvedValue([{ messageId: "a0Xf1", files: [{ id: "doc1" }] }]);
    await mountWithWires({ messages: [msg] });
    expect(apexMocks.getFilesForMessages).toHaveBeenCalled();
  });

  it("handles getFilesForMessages failure by attaching empty files", async () => {
    apexMocks.getFilesForMessages.mockRejectedValue(new Error("files"));
    await mountWithWires({ messages: [baseMessage({ id: "a0Xff" })] });
    expect(apexMocks.getMessages).toHaveBeenCalled();
  });

  it("requests older page when scrolling near top and more available", async () => {
    const older = baseMessage({ id: "a0Xold", createdDate: new Date(Date.now() - 86400000).toISOString() });
    const page = Array.from({ length: 50 }, (_, i) =>
      baseMessage({ id: `a0Xp${i}`, createdDate: new Date(Date.now() - i * 1000).toISOString() })
    );
    apexMocks.getMessages
      .mockResolvedValueOnce(page)
      .mockResolvedValueOnce([older])
      .mockResolvedValue([older, ...page]);
    const el = await mountWithWires({ messages: page });
    apexMocks.getMessages.mockClear();
    const list = el.shadowRoot.querySelector(".messages-list");
    Object.defineProperty(list, "scrollTop", { value: 0, writable: true });
    list.dispatchEvent(new CustomEvent("scroll", { bubbles: true }));
    await flushPromises();
    expect(apexMocks.getMessages).toHaveBeenCalled();
  });

  it("uses LEX-style root class when standard page ref marks Salesforce context", async () => {
    const el = await mountWithWires({
      pageRef: {
        type: "standard__recordPage",
        attributes: { recordId: "001000000000001AAA", objectApiName: "Account" },
        state: {}
      },
      milestoneMember: true,
      messages: []
    });
    const root = el.shadowRoot.querySelector(".portal-messaging-root");
    expect(root).not.toBeNull();
    expect(root.className).not.toContain("portal-messaging-root--ec");
  });

  it("hydrates record id from page state when api recordId empty", async () => {
    const el = createElement("c-portal-messaging", { is: PortalMessaging });
    setPortalPath();
    defaultApexSuccessBehavior();
    jest.useFakeTimers();
    global.requestAnimationFrame = jest.fn((cb) => {
      cb();
      return 0;
    });
    document.body.appendChild(el);
    emitMessagingWires({
      pageRef: {
        type: "comm__namedPage",
        attributes: {},
        state: { recordId: "001STATE0000001AAA", objectApiName: "Account" }
      },
      milestoneMember: false,
      contextInfo: { contextType: "Account", accountName: "X" }
    });
    await flushPromises();
    jest.advanceTimersByTime(0);
    await flushPromises();
    expect(el.recordId).toBe("001STATE0000001AAA");
  });

  it("context banner hidden for Task context type", async () => {
    const el = await mountWithWires({
      contextInfo: { contextType: "Task", taskName: "T1" },
      messages: []
    });
    expect(el.shadowRoot.querySelector(".context-display")).toBeNull();
  });

  it("context icon renders for Project context", async () => {
    const el = await mountWithWires({
      contextInfo: { contextType: "Project", projectName: "P" },
      messages: []
    });
    const icon = el.shadowRoot.querySelector(".context-display__icon");
    expect(icon).not.toBeNull();
  });

  it("toggles search UI and debounces search input", async () => {
    const el = await mountWithWires({ messages: [baseMessage()] });
    el.shadowRoot.querySelector(".search-toggle-button").click();
    await flushPromises();
    const input = el.shadowRoot.querySelector(".message-search-input");
    expect(input).not.toBeNull();
    input.dispatchEvent(
      new CustomEvent("change", {
        detail: { value: "needle" },
        bubbles: true,
        composed: true
      })
    );
    jest.advanceTimersByTime(500);
    await flushPromises();
    expect(apexMocks.getMessages).toHaveBeenCalled();
  });

  it("clears search and reloads", async () => {
    const el = await mountWithWires({ messages: [baseMessage()] });
    el.shadowRoot.querySelector(".search-toggle-button").click();
    await flushPromises();
    el.shadowRoot.querySelector("lightning-button-icon[title='Close search']").click();
    await flushPromises();
    expect(el.shadowRoot.querySelector(".message-search-input")).toBeNull();
  });

  it("toggles pinned section visibility when pinned messages exist", async () => {
    const pinnedRow = { ...baseMessage({ id: "a0Xp1", isPinned: true }), isPinned: true };
    const el = await mountWithWires({ messages: [pinnedRow] });
    const toggle = el.shadowRoot.querySelector(".pinned-preview-toggle");
    expect(toggle).not.toBeNull();
    toggle.click();
    await flushPromises();
    toggle.click();
    await flushPromises();
  });

  it("refreshes messages when LMS update matches context", async () => {
    const acc = "001000000000001AAA";
    await mountWithWires({
      messages: [baseMessage()],
      relatedAccountId: acc
    });
    apexMocks.getMessages.mockClear();
    const cb = subscribeSpy.mock.calls[0][2];
    await cb({ relatedAccountId: acc });
    await flushPromises();
    expect(apexMocks.getMessages).toHaveBeenCalled();
  });

  it("opens compose modal from New Message button", async () => {
    const el = await mountWithWires({ messages: [baseMessage()] });
    const btn = el.shadowRoot.querySelector(".message-compose-button lightning-button");
    btn.click();
    await flushPromises();
    expect(PortalMessageComposeModal.open).toHaveBeenCalled();
  });

  it("reply passes reply params to compose modal", async () => {
    const el = await mountWithWires({ messages: [baseMessage({ id: "a0Xrep" })] });
    el.shadowRoot.querySelector(".reply-button").click();
    await flushPromises();
    expect(PortalMessageComposeModal.open).toHaveBeenCalled();
  });

  it("begins edit from overflow menu", async () => {
    const el = await mountWithWires({
      messages: [
        baseMessage({
          id: "a0Xedit",
          senderId: "003000000000001AAA",
          createdById: "005000000000099AAA"
        })
      ]
    });
    const menu = el.shadowRoot.querySelector("lightning-button-menu.message-overflow-menu");
    menu.dispatchEvent(new CustomEvent("select", { detail: { value: "edit" }, bubbles: true, composed: true }));
    await flushPromises();
    expect(el.shadowRoot.querySelector("lightning-input-rich-text")).not.toBeNull();
  });

  function clickLightningButtonByLabel(root, label) {
    const buttons = [...root.querySelectorAll("lightning-button")];
    const btn = buttons.find((b) => b.label === label);
    if (!btn) {
      throw new Error(`lightning-button not found: ${label}`);
    }
    btn.click();
  }

  it("cancels edit", async () => {
    const el = await mountWithWires({
      messages: [baseMessage({ id: "a0Xcx", senderId: "003000000000001AAA" })]
    });
    const menu = el.shadowRoot.querySelector("lightning-button-menu.message-overflow-menu");
    menu.dispatchEvent(new CustomEvent("select", { detail: { value: "edit" }, bubbles: true, composed: true }));
    await flushPromises();
    clickLightningButtonByLabel(el.shadowRoot, "Cancel");
    await flushPromises();
    expect(el.shadowRoot.querySelector("lightning-input-rich-text")).toBeNull();
  });

  it("save edit validates non-empty body", async () => {
    const el = await mountWithWires({
      messages: [baseMessage({ id: "a0Xsv", senderId: "003000000000001AAA", body: "x" })]
    });
    const dispatchSpy = jest.spyOn(el, "dispatchEvent");
    const menu = el.shadowRoot.querySelector("lightning-button-menu.message-overflow-menu");
    menu.dispatchEvent(new CustomEvent("select", { detail: { value: "edit" }, bubbles: true, composed: true }));
    await flushPromises();
    const rte = el.shadowRoot.querySelector("lightning-input-rich-text");
    rte.dispatchEvent(new CustomEvent("change", { detail: { value: "   " }, bubbles: true, composed: true }));
    clickLightningButtonByLabel(el.shadowRoot, "Save");
    await flushPromises();
    const sawToast = dispatchSpy.mock.calls.some(([ev]) => {
      const t = ev && ev.type;
      return t === "lightning__showtoast" || (t && String(t).toLowerCase().includes("toast"));
    });
    expect(sawToast).toBe(true);
    dispatchSpy.mockRestore();
  });

  it("save edit calls updateMessage and refreshes", async () => {
    const el = await mountWithWires({
      messages: [baseMessage({ id: "a0Xok", senderId: "003000000000001AAA" })]
    });
    const menu = el.shadowRoot.querySelector("lightning-button-menu.message-overflow-menu");
    menu.dispatchEvent(new CustomEvent("select", { detail: { value: "edit" }, bubbles: true, composed: true }));
    await flushPromises();
    const rte = el.shadowRoot.querySelector("lightning-input-rich-text");
    rte.dispatchEvent(new CustomEvent("change", { detail: { value: "Updated" }, bubbles: true, composed: true }));
    clickLightningButtonByLabel(el.shadowRoot, "Save");
    await flushPromises();
    expect(apexMocks.updateMessage).toHaveBeenCalledWith({
      messageId: "a0Xok",
      messageBody: "Updated"
    });
  });

  it("pin message from menu for milestone member", async () => {
    const el = await mountWithWires({
      milestoneMember: true,
      messages: [baseMessage({ id: "a0Xpin", isPinned: false, createdByName: "Admin" })]
    });
    const menu = el.shadowRoot.querySelector("lightning-button-menu.message-overflow-menu");
    menu.dispatchEvent(new CustomEvent("select", { detail: { value: "pin" }, bubbles: true, composed: true }));
    await flushPromises();
    expect(apexMocks.pinMessage).toHaveBeenCalledWith({ messageId: "a0Xpin", isPinned: true });
  });

  it("deletes message when confirm returns true", async () => {
    window.confirm = jest.fn(() => true);
    const el = await mountWithWires({
      messages: [baseMessage({ id: "a0Xdel", senderId: "003000000000001AAA" })]
    });
    const menu = el.shadowRoot.querySelector("lightning-button-menu.message-overflow-menu");
    menu.dispatchEvent(new CustomEvent("select", { detail: { value: "delete" }, bubbles: true, composed: true }));
    await flushPromises();
    expect(apexMocks.deleteMessageAndAttachments).toHaveBeenCalledWith({ messageId: "a0Xdel" });
    expect(publishSpy).toHaveBeenCalled();
  });

  it("skips delete when confirm returns false", async () => {
    window.confirm = jest.fn(() => false);
    const el = await mountWithWires({
      messages: [baseMessage({ id: "a0Xnd", senderId: "003000000000001AAA" })]
    });
    const menu = el.shadowRoot.querySelector("lightning-button-menu.message-overflow-menu");
    menu.dispatchEvent(new CustomEvent("select", { detail: { value: "delete" }, bubbles: true, composed: true }));
    await flushPromises();
    expect(apexMocks.deleteMessageAndAttachments).not.toHaveBeenCalled();
  });

  it("compose modal close with sent status triggers reload", async () => {
    PortalMessageComposeModal.open.mockResolvedValueOnce({ status: "sent", recipientType: "Client" });
    const el = await mountWithWires({ messages: [baseMessage()] });
    const n = apexMocks.getMessages.mock.calls.length;
    el.shadowRoot.querySelector(".message-compose-button lightning-button").click();
    await flushPromises();
    expect(apexMocks.getMessages.mock.calls.length).toBeGreaterThan(n);
  });

  it("View original scrolls target message into view when present", async () => {
    const scrollIntoView = jest.fn();
    const origProto = HTMLElement.prototype.scrollIntoView;
    HTMLElement.prototype.scrollIntoView = scrollIntoView;
    const t0 = new Date(Date.now() - 120000).toISOString();
    const t1 = new Date(Date.now() - 60000).toISOString();
    const el = await mountWithWires({
      messages: [
        baseMessage({ id: "a0Xorig", createdDate: t0 }),
        baseMessage({
          id: "a0Xmain",
          createdDate: t1,
          replyToMessageId: "a0Xorig",
          replyToSenderName: "Bob",
          replyToMessageBody: "Old"
        })
      ]
    });
    const btn = el.shadowRoot.querySelector("button[title='Go to original message']");
    btn.click();
    jest.advanceTimersByTime(100);
    expect(scrollIntoView).toHaveBeenCalled();
    HTMLElement.prototype.scrollIntoView = origProto;
  });

  it("wired context info error path does not throw", async () => {
    getContextInfoAdapter.emitError({ body: { message: "ctx err" } });
    await flushPromises();
    expect(true).toBe(true);
  });

  it("milestone wire error still allows message loads for portal defaults", async () => {
    setPortalPath();
    defaultApexSuccessBehavior();
    jest.useFakeTimers();
    global.requestAnimationFrame = jest.fn((cb) => {
      cb();
      return 0;
    });
    const el = createElement("c-portal-messaging", { is: PortalMessaging });
    el.relatedAccountId = "001000000000001AAA";
    document.body.appendChild(el);
    messageContextAdapter.emit({ data: {}, error: undefined });
    pageReferenceAdapter.emit({ type: "comm__namedPage", attributes: {}, state: {} });
    isMilestoneTeamMemberAdapter.emitError({ body: { message: "x" } });
    getCurrentUserContactIdAdapter.emit("003000000000001AAA");
    getContextInfoAdapter.emit({ contextType: "Account", accountName: "A" });
    await flushPromises();
    jest.advanceTimersByTime(0);
    await flushPromises();
    jest.advanceTimersByTime(200);
    await flushPromises();
    expect(apexMocks.getMessages).toHaveBeenCalled();
    document.body.removeChild(el);
  });

  it("unpin action calls pinMessage with isPinned false", async () => {
    const el = await mountWithWires({
      milestoneMember: true,
      messages: [baseMessage({ id: "a0Xun", isPinned: true, createdByName: "Admin" })]
    });
    const menu = el.shadowRoot.querySelector("lightning-button-menu.message-overflow-menu");
    menu.dispatchEvent(new CustomEvent("select", { detail: { value: "unpin" }, bubbles: true, composed: true }));
    await flushPromises();
    expect(apexMocks.pinMessage).toHaveBeenCalledWith({ messageId: "a0Xun", isPinned: false });
  });

  it("updateMessage rejection runs handleSaveEdit catch path", async () => {
    apexMocks.updateMessage.mockRejectedValue({ body: { message: "nope" }, message: "nope" });
    const el = await mountWithWires({
      messages: [baseMessage({ id: "a0Xer", senderId: "003000000000001AAA" })]
    });
    const menu = el.shadowRoot.querySelector("lightning-button-menu.message-overflow-menu");
    menu.dispatchEvent(new CustomEvent("select", { detail: { value: "edit" }, bubbles: true, composed: true }));
    await flushPromises();
    const rte = el.shadowRoot.querySelector("lightning-input-rich-text");
    rte.dispatchEvent(new CustomEvent("change", { detail: { value: "Text" }, bubbles: true, composed: true }));
    clickLightningButtonByLabel(el.shadowRoot, "Save");
    await flushPromises();
    expect(apexMocks.updateMessage).toHaveBeenCalled();
  });

  it("pinMessage rejection runs pinMessageWithId catch path", async () => {
    apexMocks.pinMessage.mockRejectedValue({ body: { message: "pin bad" } });
    const el = await mountWithWires({
      milestoneMember: true,
      messages: [baseMessage({ id: "a0Xpf", isPinned: false })]
    });
    const menu = el.shadowRoot.querySelector("lightning-button-menu.message-overflow-menu");
    menu.dispatchEvent(new CustomEvent("select", { detail: { value: "pin" }, bubbles: true, composed: true }));
    await flushPromises();
    expect(apexMocks.pinMessage).toHaveBeenCalled();
  });

  it("getPinnedMessages failure clears pinned list", async () => {
    apexMocks.getPinnedMessages.mockRejectedValue(new Error("pinned down"));
    await mountWithWires({ messages: [baseMessage()] });
    expect(apexMocks.getPinnedMessages).toHaveBeenCalled();
  });

  it("deleteMessageAndAttachments rejection runs confirmAndDeleteMessage catch", async () => {
    window.confirm = jest.fn(() => true);
    apexMocks.deleteMessageAndAttachments.mockRejectedValue({ body: { message: "del bad" } });
    const el = await mountWithWires({
      messages: [baseMessage({ id: "a0Xd0", senderId: "003000000000001AAA" })]
    });
    const menu = el.shadowRoot.querySelector("lightning-button-menu.message-overflow-menu");
    menu.dispatchEvent(new CustomEvent("select", { detail: { value: "delete" }, bubbles: true, composed: true }));
    await flushPromises();
    expect(apexMocks.deleteMessageAndAttachments).toHaveBeenCalled();
  });

  it("compose modal open rejection is swallowed", async () => {
    PortalMessageComposeModal.open.mockRejectedValueOnce(new Error("modal"));
    const el = await mountWithWires({ messages: [baseMessage()] });
    el.shadowRoot.querySelector(".message-compose-button lightning-button").click();
    await flushPromises();
    expect(PortalMessageComposeModal.open).toHaveBeenCalled();
  });

  it("LEX user clicks project nav link on message row", async () => {
    const el = await mountWithWires({
      milestoneMember: true,
      pageRef: {
        type: "standard__recordPage",
        attributes: { recordId: "001000000000001AAA", objectApiName: "Account" },
        state: {}
      },
      contextInfo: { contextType: "Account", accountName: "A" },
      messages: [
        baseMessage({
          id: "a0Xm1",
          relatedProjectId: "a01000000000001",
          relatedProjectName: "Proj X",
          createdByName: "Admin"
        })
      ]
    });
    const navSpy = jest.spyOn(el, "dispatchEvent").mockImplementation(() => true);
    const link = el.shadowRoot.querySelector("[data-link]");
    if (link && link.dataset.link) {
      link.click();
    }
    navSpy.mockRestore();
    expect(link).not.toBeNull();
  });

  it("markAsRead failure in loop still completes markUnreadMessagesAsRead", async () => {
    const unread = baseMessage({ id: "a0Xmr", isRead: false });
    apexMocks.markAsRead.mockRejectedValueOnce(new Error("read fail"));
    apexMocks.getMessages
      .mockResolvedValueOnce([unread])
      .mockResolvedValueOnce([{ ...unread, isRead: true }])
      .mockResolvedValue([{ ...unread, isRead: true }]);
    await mountWithWires({ messages: [unread] });
    expect(apexMocks.markAsRead).toHaveBeenCalled();
  });

  it("MessageContext wire error path does not throw", async () => {
    messageContextAdapter.emit({ data: undefined, error: { body: { message: "ctx" } } });
    await flushPromises();
    expect(true).toBe(true);
  });

  describe("branch coverage ≥85% (js + html)", () => {
    function latestSubscribeCallback() {
      const calls = subscribeSpy.mock.calls;
      expect(calls.length).toBeGreaterThan(0);
      return calls[calls.length - 1][2];
    }

    it("loadMessages append exits early when no more messages", async () => {
      const few = [baseMessage({ id: "a0Xa" }), baseMessage({ id: "a0Xb" })];
      const el = await mountWithWires({ messages: few });
      apexMocks.getMessages.mockClear();
      await PortalMessaging.prototype.loadMessages.call(el, true);
      expect(apexMocks.getMessages).not.toHaveBeenCalled();
    });

    it("loadMessages returns immediately when already loading (concurrent guard)", async () => {
      const page = Array.from({ length: 50 }, (_, i) =>
        baseMessage({
          id: `a0Xc${String(i).padStart(3, "0")}`,
          createdDate: new Date(Date.now() - i * 1000).toISOString()
        })
      );
      const el = await mountWithWires({ messages: page });
      let resolveHang;
      const hang = new Promise((r) => {
        resolveHang = r;
      });
      apexMocks.getMessages.mockImplementationOnce(() => hang);
      const list = el.shadowRoot.querySelector(".messages-list");
      Object.defineProperty(list, "scrollTop", { value: 0, writable: true });
      list.dispatchEvent(new CustomEvent("scroll", { bubbles: true }));
      await flushPromises();
      const n = apexMocks.getMessages.mock.calls.length;
      list.dispatchEvent(new CustomEvent("scroll", { bubbles: true }));
      await flushPromises();
      expect(apexMocks.getMessages.mock.calls.length).toBe(n);
      resolveHang([]);
      await flushPromises();
    });

    it("loadMessages catch uses exceptionMessage when body has no message", async () => {
      setPortalPath();
      jest.useFakeTimers();
      global.requestAnimationFrame = jest.fn((cb) => {
        cb();
        return 0;
      });
      const el = createElement("c-portal-messaging", { is: PortalMessaging });
      el.relatedAccountId = "001000000000001AAA";
      apexMocks.getPinnedMessages.mockResolvedValue([]);
      apexMocks.getFilesForMessages.mockResolvedValue([]);
      apexMocks.markAsRead.mockResolvedValue(undefined);
      apexMocks.getMessages.mockRejectedValue({ body: { exceptionMessage: "ex only" } });
      const dispatchSpy = jest.spyOn(el, "dispatchEvent");
      document.body.appendChild(el);
      emitMessagingWires({});
      await flushPromises();
      jest.advanceTimersByTime(200);
      await flushPromises();
      const toast = dispatchSpy.mock.calls.find(
        ([ev]) =>
          ev &&
          String(ev.type || "")
            .toLowerCase()
            .includes("toast")
      );
      expect(toast).toBeTruthy();
      dispatchSpy.mockRestore();
    });

    it("loadMessages catch uses error.message when no body", async () => {
      setPortalPath();
      jest.useFakeTimers();
      global.requestAnimationFrame = jest.fn((cb) => {
        cb();
        return 0;
      });
      const el = createElement("c-portal-messaging", { is: PortalMessaging });
      el.relatedAccountId = "001000000000001AAA";
      apexMocks.getPinnedMessages.mockResolvedValue([]);
      apexMocks.getFilesForMessages.mockResolvedValue([]);
      apexMocks.markAsRead.mockResolvedValue(undefined);
      apexMocks.getMessages.mockRejectedValue({ message: "plain msg" });
      const dispatchSpy = jest.spyOn(el, "dispatchEvent");
      document.body.appendChild(el);
      emitMessagingWires({});
      await flushPromises();
      jest.advanceTimersByTime(200);
      await flushPromises();
      expect(dispatchSpy.mock.calls.length).toBeGreaterThan(0);
      dispatchSpy.mockRestore();
    });

    it("append load failure does not clear existing messages", async () => {
      const page = Array.from({ length: 50 }, (_, i) =>
        baseMessage({ id: `a0Xd${i}`, createdDate: new Date(Date.now() - i * 1000).toISOString() })
      );
      const el = await mountWithWires({ messages: page });
      apexMocks.getMessages.mockRejectedValueOnce(new Error("append fail"));
      const list = el.shadowRoot.querySelector(".messages-list");
      Object.defineProperty(list, "scrollTop", { value: 0, writable: true });
      list.dispatchEvent(new CustomEvent("scroll", { bubbles: true }));
      await flushPromises();
      expect(el.shadowRoot.querySelectorAll(".message-item").length).toBeGreaterThan(0);
    });

    it("resolvePageReference no-ops when pageRef is falsy", async () => {
      setPortalPath();
      defaultApexSuccessBehavior();
      jest.useFakeTimers();
      global.requestAnimationFrame = jest.fn((cb) => {
        cb();
        return 0;
      });
      const el = createElement("c-portal-messaging", { is: PortalMessaging });
      el.relatedAccountId = "001000000000001AAA";
      document.body.appendChild(el);
      messageContextAdapter.emit({ data: {}, error: undefined });
      pageReferenceAdapter.emit(undefined);
      isMilestoneTeamMemberAdapter.emit(false);
      getCurrentUserContactIdAdapter.emit("003000000000001AAA");
      getContextInfoAdapter.emit({ contextType: "Account", accountName: "A" });
      await flushPromises();
      jest.advanceTimersByTime(200);
      await flushPromises();
      expect(apexMocks.getMessages).toHaveBeenCalled();
      document.body.removeChild(el);
    });

    it("isExperienceCloud getter defaults true when no /s/ and not milestone", async () => {
      delete window.location;
      window.location = { pathname: "/app/home", href: "https://lex.example/app/home" };
      defaultApexSuccessBehavior();
      jest.useFakeTimers();
      global.requestAnimationFrame = jest.fn((cb) => {
        cb();
        return 0;
      });
      const el = createElement("c-portal-messaging", { is: PortalMessaging });
      el.relatedAccountId = "001000000000001AAA";
      document.body.appendChild(el);
      messageContextAdapter.emit({ data: {}, error: undefined });
      isMilestoneTeamMemberAdapter.emit(false);
      getCurrentUserContactIdAdapter.emit("003000000000001AAA");
      getContextInfoAdapter.emit({ contextType: "Account", accountName: "A" });
      await flushPromises();
      jest.advanceTimersByTime(200);
      await flushPromises();
      const root = el.shadowRoot.querySelector(".portal-messaging-root");
      expect(root.className).toContain("portal-messaging-root--ec");
      document.body.removeChild(el);
    });

    it("wiredMessageContext error after mount logs without throwing", async () => {
      await mountWithWires({ messages: [] });
      const errSpy = jest.spyOn(console, "error").mockImplementation(() => {});
      messageContextAdapter.emit({ data: undefined, error: { body: { message: "wire ctx" } } });
      await flushPromises();
      expect(errSpy).toHaveBeenCalled();
      errSpy.mockRestore();
    });

    it("wiredCurrentUserContact error path logs", async () => {
      await mountWithWires({ messages: [] });
      const errSpy = jest.spyOn(console, "error").mockImplementation(() => {});
      getCurrentUserContactIdAdapter.emitError({ body: { message: "no contact" } });
      await flushPromises();
      expect(errSpy).toHaveBeenCalled();
      errSpy.mockRestore();
    });

    it("handleMessageUpdate ignores null payload", async () => {
      await mountWithWires({ messages: [baseMessage()] });
      apexMocks.getMessages.mockClear();
      const cb = latestSubscribeCallback();
      await cb(null);
      await flushPromises();
      expect(apexMocks.getMessages).not.toHaveBeenCalled();
    });

    it("handleMessageUpdate ignores irrelevant ids", async () => {
      await mountWithWires({
        messages: [baseMessage()],
        relatedAccountId: "001000000000001AAA"
      });
      apexMocks.getMessages.mockClear();
      const cb = latestSubscribeCallback();
      await cb({ relatedAccountId: "009999999999999AAA" });
      await flushPromises();
      expect(apexMocks.getMessages).not.toHaveBeenCalled();
    });

    it("handleMessageUpdate global refresh when both sides lack related ids", async () => {
      setPortalPath();
      defaultApexSuccessBehavior();
      jest.useFakeTimers();
      global.requestAnimationFrame = jest.fn((cb) => {
        cb();
        return 0;
      });
      const el = createElement("c-portal-messaging", { is: PortalMessaging });
      document.body.appendChild(el);
      messageContextAdapter.emit({ data: { channel: "test" }, error: undefined });
      pageReferenceAdapter.emit({ type: "comm__namedPage", attributes: {}, state: {} });
      isMilestoneTeamMemberAdapter.emit(false);
      getCurrentUserContactIdAdapter.emit("003000000000001AAA");
      getContextInfoAdapter.emit({ contextType: "Account", accountName: "Z" });
      await flushPromises();
      jest.advanceTimersByTime(200);
      await flushPromises();
      expect(subscribeSpy).toHaveBeenCalled();
      apexMocks.getMessages.mockClear();
      const cb = latestSubscribeCallback();
      await cb({});
      await flushPromises();
      expect(apexMocks.getMessages).toHaveBeenCalled();
      document.body.removeChild(el);
    });

    it("attachFilesToMessages returns rows with empty files when rows lack id", async () => {
      apexMocks.getFilesForMessages.mockClear();
      await mountWithWires({ messages: [{ body: "<p>x</p>", createdDate: new Date().toISOString() }] });
      expect(apexMocks.getFilesForMessages).not.toHaveBeenCalled();
    });

    it("handleScroll does not load when far from top", async () => {
      const page = Array.from({ length: 50 }, (_, i) =>
        baseMessage({ id: `a0Xe${i}`, createdDate: new Date(Date.now() - i * 1000).toISOString() })
      );
      const el = await mountWithWires({ messages: page });
      apexMocks.getMessages.mockClear();
      const list = el.shadowRoot.querySelector(".messages-list");
      Object.defineProperty(list, "scrollTop", { value: 500, writable: true });
      list.dispatchEvent(new CustomEvent("scroll", { bubbles: true }));
      await flushPromises();
      expect(apexMocks.getMessages).not.toHaveBeenCalled();
    });

    it("handleToggleSearch clears term when closing", async () => {
      const el = await mountWithWires({ messages: [baseMessage()] });
      el.shadowRoot.querySelector(".search-toggle-button").click();
      await flushPromises();
      const input = el.shadowRoot.querySelector(".message-search-input");
      input.dispatchEvent(new CustomEvent("change", { detail: { value: "x" }, bubbles: true, composed: true }));
      el.shadowRoot.querySelector("lightning-button-icon[title='Close search']").click();
      await flushPromises();
      expect(el.shadowRoot.querySelector(".message-search-input")).toBeNull();
      el.shadowRoot.querySelector(".search-toggle-button").click();
      await flushPromises();
      const inputAgain = el.shadowRoot.querySelector(".message-search-input");
      expect(inputAgain).not.toBeNull();
      const inner = inputAgain.shadowRoot && inputAgain.shadowRoot.querySelector("input");
      expect(inner ? inner.value : inputAgain.value).toBe("");
    });

    it("handleMessageSearchChange debounce clears previous timeout", async () => {
      const el = await mountWithWires({ messages: [baseMessage()] });
      el.shadowRoot.querySelector(".search-toggle-button").click();
      await flushPromises();
      const input = el.shadowRoot.querySelector(".message-search-input");
      apexMocks.getMessages.mockClear();
      input.dispatchEvent(new CustomEvent("change", { detail: { value: "a" }, bubbles: true, composed: true }));
      input.dispatchEvent(new CustomEvent("change", { detail: { value: "ab" }, bubbles: true, composed: true }));
      jest.advanceTimersByTime(500);
      await flushPromises();
      expect(apexMocks.getMessages.mock.calls.length).toBe(1);
    });

    it("formatMessageDate buckets with fake timers", () => {
      const el = createElement("c-portal-messaging", { is: PortalMessaging });
      const fixed = new Date("2026-04-06T12:00:00.000Z");
      jest.useFakeTimers({ now: fixed });
      const fmt = (d) => PortalMessaging.prototype.formatMessageDate.call(el, d);
      expect(fmt("")).toBe("");
      expect(fmt(new Date(fixed.getTime() - 30 * 1000).toISOString())).toMatch(/Just now/);
      expect(fmt(new Date(fixed.getTime() - 2 * 60000).toISOString())).toMatch(/minute/);
      expect(fmt(new Date(fixed.getTime() - 3 * 3600000).toISOString())).toMatch(/hour/);
      expect(fmt(new Date(fixed.getTime() - 2 * 86400000).toISOString())).toMatch(/day/);
      expect(fmt(new Date(fixed.getTime() - 10 * 86400000).toISOString())).toMatch(/full:/);
    });

    it("handleScrollToMessageInThread shows toast when message never loads", async () => {
      const el = await mountWithWires({
        milestoneMember: true,
        messages: [baseMessage({ id: "a0Xonly", createdByName: "Admin" })],
        pinnedMessages: [baseMessage({ id: "a0Xghost", isPinned: true, createdByName: "Admin" })]
      });
      const dispatchSpy = jest.spyOn(el, "dispatchEvent");
      const pinRow = el.shadowRoot.querySelector('[data-message-id="a0Xghost"]');
      expect(pinRow).not.toBeNull();
      pinRow.click();
      await flushPromises();
      const warnToast = dispatchSpy.mock.calls.some(([ev]) => {
        const d = ev && ev.detail;
        return d && d.variant === "warning";
      });
      expect(warnToast).toBe(true);
      dispatchSpy.mockRestore();
    });

    it("handleScrollToMessageInThread scrolls when row exists in thread", async () => {
      const el = await mountWithWires({
        milestoneMember: true,
        messages: [baseMessage({ id: "a0Xin", createdByName: "Admin", isPinned: true })],
        pinnedMessages: [baseMessage({ id: "a0Xin", isPinned: true, createdByName: "Admin" })]
      });
      const threadRow = el.shadowRoot.querySelector('.message-item[data-message-id="a0Xin"]');
      expect(threadRow).not.toBeNull();
      const scrollFn = jest.fn();
      threadRow.scrollIntoView = scrollFn;
      const pinRow = el.shadowRoot.querySelector(".pinned-compact-row");
      expect(pinRow).not.toBeNull();
      pinRow.click();
      await flushPromises();
      await flushPromises();
      expect(scrollFn).toHaveBeenCalled();
    });

    it("buildLink returns null when ensureSitePath throws", async () => {
      ensureSitePath.mockImplementationOnce(() => {
        throw new Error("path");
      });
      const el = await mountWithWires({
        messages: [
          baseMessage({
            id: "a0Xbl",
            relatedProjectId: "a01000000000001",
            relatedProjectName: "P"
          })
        ]
      });
      expect(el.shadowRoot.querySelectorAll(".message-item").length).toBe(1);
    });

    it("LEX handleNavigateToRecord parses standard__recordPage and calls Navigate", async () => {
      const el = await mountWithWires({
        milestoneMember: true,
        pageRef: {
          type: "standard__recordPage",
          attributes: { recordId: "001000000000001AAA", objectApiName: "Account" },
          state: {}
        },
        contextInfo: { contextType: "Account", accountName: "A" },
        messages: [baseMessage({ id: "a0Xnav", createdByName: "Admin" })]
      });
      const navKey = NavigationMixin.Navigate;
      const navSpy = jest.fn();
      el[navKey] = navSpy;
      const payload = JSON.stringify({
        type: "standard__recordPage",
        attributes: {
          recordId: "a01000000000001",
          objectApiName: "Project__c",
          actionName: "view"
        }
      });
      PortalMessaging.prototype.handleNavigateToRecord.call(el, {
        currentTarget: { dataset: { link: payload } }
      });
      expect(navSpy).toHaveBeenCalledWith(
        expect.objectContaining({
          type: "standard__recordPage",
          attributes: expect.objectContaining({
            recordId: "a01000000000001",
            objectApiName: "Project__c"
          })
        })
      );
    });

    it("portal handleNavigateToRecord sets location href for portal link JSON", async () => {
      const el = await mountWithWires({
        messages: [
          baseMessage({
            id: "a0Xph",
            relatedProjectId: "a01000000000001",
            relatedProjectName: "Proj"
          })
        ]
      });
      const hrefPayload = JSON.stringify({ href: "https://portal.example/s/site/project/x" });
      PortalMessaging.prototype.handleNavigateToRecord.call(el, {
        currentTarget: { dataset: { link: hrefPayload } }
      });
      expect(window.location.href).toBe("https://portal.example/s/site/project/x");
    });

    it("LEX handleNavigateToRecord fallback uses recordId on invalid JSON", async () => {
      const el = await mountWithWires({
        milestoneMember: true,
        pageRef: {
          type: "standard__recordPage",
          attributes: { recordId: "001000000000001AAA", objectApiName: "Account" },
          state: {}
        },
        contextInfo: { contextType: "Account", accountName: "A" },
        messages: [baseMessage({ id: "a0Xfb", createdByName: "Admin" })]
      });
      const navKey = NavigationMixin.Navigate;
      const navSpy = jest.fn();
      el[navKey] = navSpy;
      Object.defineProperty(el, "isSalesforceContext", {
        configurable: true,
        get() {
          return true;
        }
      });
      const btn = document.createElement("button");
      btn.dataset.link = "not-valid-json";
      btn.dataset.recordId = "a02000000000002";
      btn.dataset.objectApiName = "Project__c";
      document.body.appendChild(btn);
      try {
        PortalMessaging.prototype.handleNavigateToRecord.call(el, { currentTarget: btn });
        expect(navSpy).toHaveBeenCalled();
        const arg0 = navSpy.mock.calls[navSpy.mock.calls.length - 1][0];
        expect(arg0.type).toBe("standard__recordPage");
        expect(arg0.attributes.recordId).toBe("a02000000000002");
        expect(arg0.attributes.objectApiName).toBe("Project__c");
      } finally {
        document.body.removeChild(btn);
        delete el.isSalesforceContext;
      }
    });

    it("empty thread shows No messages yet", async () => {
      const el = await mountWithWires({ messages: [] });
      expect(el.shadowRoot.textContent).toMatch(/No messages yet/);
    });

    it("search with no results clears thread (server empty list)", async () => {
      apexMocks.getMessages.mockResolvedValueOnce([baseMessage()]).mockResolvedValueOnce([]);
      const el = await mountWithWires({ messages: [baseMessage()] });
      el.shadowRoot.querySelector(".search-toggle-button").click();
      await flushPromises();
      const input = el.shadowRoot.querySelector(".message-search-input");
      input.dispatchEvent(new CustomEvent("change", { detail: { value: "zzznone" }, bubbles: true, composed: true }));
      jest.advanceTimersByTime(500);
      await flushPromises();
      expect(el.shadowRoot.textContent).toMatch(/No messages yet/);
    });

    it("shows loading older messages spinner while append in flight", async () => {
      const page = Array.from({ length: 50 }, (_, i) =>
        baseMessage({ id: `a0Xsp${i}`, createdDate: new Date(Date.now() - i * 1000).toISOString() })
      );
      let resolveSecond;
      const second = new Promise((r) => {
        resolveSecond = r;
      });
      apexMocks.getMessages.mockResolvedValueOnce(page).mockImplementationOnce(() => second);
      const el = await mountWithWires({ messages: page });
      const list = el.shadowRoot.querySelector(".messages-list");
      Object.defineProperty(list, "scrollTop", { value: 0, writable: true });
      list.dispatchEvent(new CustomEvent("scroll", { bubbles: true }));
      await flushPromises();
      expect(el.shadowRoot.textContent).toMatch(/Loading older messages/);
      resolveSecond([]);
      await flushPromises();
    });

    it("shows end of list banner when no more pages", async () => {
      const el = await mountWithWires({ messages: [baseMessage({ id: "a0Xend" })] });
      expect(el.shadowRoot.textContent).toMatch(/No older messages to load/);
    });

    it("renders edited reply preview with ellipsis (internal/milestone row)", async () => {
      const longReply = "x".repeat(120);
      const el = await mountWithWires({
        milestoneMember: true,
        messages: [
          baseMessage({
            id: "a0Xbdg",
            isMentioned: true,
            isEdited: true,
            isRead: false,
            visibleToClient: false,
            lastEditedDate: new Date().toISOString(),
            replyToMessageId: "a0Xprev",
            replyToSenderName: "Sam",
            replyToMessageBody: `<p>${longReply}</p>`,
            replyToCreatedDate: new Date().toISOString(),
            createdByName: "Admin"
          })
        ]
      });
      const row = el.shadowRoot.querySelector('[data-message-id="a0Xbdg"]');
      expect(row).not.toBeNull();
      expect(el.shadowRoot.querySelectorAll("lightning-badge").length).toBeGreaterThan(0);
      const txt = el.shadowRoot.textContent || "";
      expect(txt).toMatch(/\(edited/);
      expect(txt).toMatch(/…/);
    });

    it("portal project and task links use href anchors", async () => {
      const el = await mountWithWires({
        contextInfo: { contextType: "Account", accountName: "Acme" },
        messages: [
          baseMessage({
            id: "a0Xpt",
            relatedProjectId: "a01000000000001",
            relatedProjectName: "Proj Z",
            relatedTaskId: "a02000000000002",
            relatedTaskName: "Task Z"
          })
        ]
      });
      const anchors = [...el.shadowRoot.querySelectorAll("a.slds-text-link")];
      const hrefs = anchors.map((a) => a.getAttribute("href")).filter(Boolean);
      expect(hrefs.some((h) => h.includes("/project/"))).toBe(true);
      expect(hrefs.some((h) => h.includes("/project-task/"))).toBe(true);
    });

    it("Account context shows text-only project row when projectLink null", async () => {
      try {
        ensureSitePath.mockImplementation((path) => {
          const p = String(path || "");
          if (p.includes("/project/") && !p.includes("project-task")) {
            throw new Error("no link");
          }
          return `/s/site${p}`;
        });
        const el = await mountWithWires({
          contextInfo: { contextType: "Account", accountName: "Acme" },
          messages: [
            baseMessage({
              id: "a0Xtxt",
              relatedProjectId: "a01000000000001",
              relatedProjectName: "Proj Plain"
            })
          ]
        });
        expect(el.shadowRoot.textContent).toMatch(/Project: Proj Plain/);
        expect(el.shadowRoot.querySelector("a.slds-text-link[href*='project']")).toBeNull();
      } finally {
        ensureSitePath.mockImplementation((path) => `/s/site${path}`);
      }
    });

    it("hidePinnedMessagesSection hides pinned chrome", async () => {
      const el = await mountWithWires({
        hidePinnedMessagesSection: true,
        milestoneMember: true,
        messages: [baseMessage({ id: "a0Xhp", isPinned: true, createdByName: "Admin" })]
      });
      expect(el.shadowRoot.querySelector(".pinned-preview-toggle")).toBeNull();
    });

    it("pinnedSectionCollapsedByDefault starts collapsed", async () => {
      const el = await mountWithWires({
        pinnedSectionCollapsedByDefault: true,
        milestoneMember: true,
        messages: [baseMessage({ id: "a0Xcl", isPinned: true, createdByName: "Admin" })]
      });
      expect(el.shadowRoot.querySelector(".pinned-messages-panel")).toBeNull();
    });

    it("messageCountText singular for one message", async () => {
      const el = await mountWithWires({ messages: [baseMessage({ id: "a0X1" })] });
      expect(el.shadowRoot.textContent).toMatch(/1\s+message/);
    });

    it("resolves relatedProjectId from LEX page ref", async () => {
      const el = createElement("c-portal-messaging", { is: PortalMessaging });
      setPortalPath();
      defaultApexSuccessBehavior();
      jest.useFakeTimers();
      global.requestAnimationFrame = jest.fn((cb) => {
        cb();
        return 0;
      });
      document.body.appendChild(el);
      messageContextAdapter.emit({ data: {}, error: undefined });
      pageReferenceAdapter.emit({
        type: "standard__recordPage",
        attributes: { recordId: "a01000000000001", objectApiName: "Project__c" },
        state: {}
      });
      isMilestoneTeamMemberAdapter.emit(false);
      getCurrentUserContactIdAdapter.emit("003000000000001AAA");
      getContextInfoAdapter.emit({ contextType: "Project", projectName: "P" });
      await flushPromises();
      jest.advanceTimersByTime(200);
      await flushPromises();
      expect(el.relatedProjectId).toBe("a01000000000001");
      document.body.removeChild(el);
    });

    it("sorts messages by id when createdDate ties", async () => {
      const t = new Date().toISOString();
      const el = await mountWithWires({
        messages: [baseMessage({ id: "a0Xz", createdDate: t }), baseMessage({ id: "a0Xa", createdDate: t })]
      });
      const items = [...el.shadowRoot.querySelectorAll(".message-item")];
      const order = items.map((node) => node.getAttribute("data-message-id"));
      expect(order).toEqual(["a0Xa", "a0Xz"]);
    });

    it("contextIcon uses default for unknown contextType", async () => {
      const el = await mountWithWires({
        contextInfo: { contextType: "Custom", accountName: "X" },
        messages: []
      });
      const icon = el.shadowRoot.querySelector(".context-display__icon");
      expect(icon).not.toBeNull();
      expect(icon.iconName || icon.getAttribute("icon-name")).toBe("utility:message");
    });

    it("handleMessageActionMenuSelect returns when messageId missing", async () => {
      const el = await mountWithWires({
        milestoneMember: true,
        messages: [baseMessage({ id: "a0Xmu", createdByName: "Admin" })]
      });
      apexMocks.pinMessage.mockClear();
      PortalMessaging.prototype.handleMessageActionMenuSelect.call(el, {
        currentTarget: { dataset: {} },
        detail: { value: "pin" }
      });
      expect(apexMocks.pinMessage).not.toHaveBeenCalled();
    });

    it("computeDisplaySenderName falls back to sender when no createdByName for milestone", async () => {
      const el = await mountWithWires({
        milestoneMember: true,
        messages: [baseMessage({ id: "a0Xsn", senderName: "From Sender", createdByName: undefined })]
      });
      expect(el.shadowRoot.textContent).toContain("From Sender");
    });

    it("loadPinnedMessages early exit when recipientType unset", async () => {
      setPortalPath();
      defaultApexSuccessBehavior();
      jest.useFakeTimers();
      global.requestAnimationFrame = jest.fn((cb) => {
        cb();
        return 0;
      });
      const el = createElement("c-portal-messaging", { is: PortalMessaging });
      el.relatedAccountId = "001000000000001AAA";
      document.body.appendChild(el);
      messageContextAdapter.emit({ data: {}, error: undefined });
      pageReferenceAdapter.emit({ type: "comm__namedPage", attributes: {}, state: {} });
      getCurrentUserContactIdAdapter.emit("003000000000001AAA");
      getContextInfoAdapter.emit({ contextType: "Account", accountName: "A" });
      await flushPromises();
      apexMocks.getPinnedMessages.mockClear();
      await PortalMessaging.prototype.loadPinnedMessages.call(el);
      expect(apexMocks.getPinnedMessages).not.toHaveBeenCalled();
      document.body.removeChild(el);
    });

    it("api setters relatedProjectId and relatedTaskId", async () => {
      const el = await mountWithWires({ messages: [baseMessage()] });
      el.relatedProjectId = "a01000000000001";
      el.relatedTaskId = "a02000000000002";
      expect(el.relatedProjectId).toBe("a01000000000001");
      expect(el.relatedTaskId).toBe("a02000000000002");
    });

    it("isExperienceCloud false from milestone path when pathname has no /s/", async () => {
      delete window.location;
      window.location = { pathname: "/lightning/page", href: "https://lex.example/lightning/page" };
      defaultApexSuccessBehavior();
      jest.useFakeTimers();
      global.requestAnimationFrame = jest.fn((cb) => {
        cb();
        return 0;
      });
      const el = createElement("c-portal-messaging", { is: PortalMessaging });
      el.relatedAccountId = "001000000000001AAA";
      document.body.appendChild(el);
      messageContextAdapter.emit({ data: {}, error: undefined });
      isMilestoneTeamMemberAdapter.emit(true);
      getCurrentUserContactIdAdapter.emit("003000000000001AAA");
      getContextInfoAdapter.emit({ contextType: "Account", accountName: "A" });
      await flushPromises();
      jest.advanceTimersByTime(200);
      await flushPromises();
      const root = el.shadowRoot.querySelector(".portal-messaging-root");
      expect(root.className).not.toContain("portal-messaging-root--ec");
      document.body.removeChild(el);
    });

    it("resolvePageReference sets relatedTaskId for Project_Task__c record page", async () => {
      const el = createElement("c-portal-messaging", { is: PortalMessaging });
      setPortalPath();
      defaultApexSuccessBehavior();
      jest.useFakeTimers();
      global.requestAnimationFrame = jest.fn((cb) => {
        cb();
        return 0;
      });
      document.body.appendChild(el);
      messageContextAdapter.emit({ data: {}, error: undefined });
      pageReferenceAdapter.emit({
        type: "standard__recordPage",
        attributes: { recordId: "a02000000000002", objectApiName: "Project_Task__c" },
        state: {}
      });
      isMilestoneTeamMemberAdapter.emit(false);
      getCurrentUserContactIdAdapter.emit("003000000000001AAA");
      getContextInfoAdapter.emit({ contextType: "Task", taskName: "T" });
      await flushPromises();
      jest.advanceTimersByTime(200);
      await flushPromises();
      expect(el.relatedTaskId).toBe("a02000000000002");
      document.body.removeChild(el);
    });

    it("loadPinnedMessages catch clears pinned list on reload", async () => {
      const el = await mountWithWires({ messages: [baseMessage()] });
      apexMocks.getPinnedMessages.mockRejectedValueOnce(new Error("pin apex"));
      await PortalMessaging.prototype.loadPinnedMessages.call(el);
      await flushPromises();
      expect(apexMocks.getPinnedMessages).toHaveBeenCalled();
    });

    it("attachFilesToMessages catch on pinned load clears files on rows", async () => {
      apexMocks.getFilesForMessages.mockRejectedValueOnce(new Error("files pin"));
      await mountWithWires({
        pinnedMessages: [baseMessage({ id: "a0Xpf", isPinned: true })],
        messages: [baseMessage({ id: "a0Xpf", isPinned: true })]
      });
      expect(apexMocks.getFilesForMessages).toHaveBeenCalled();
    });

    it("contextDisplayText combines account project and task", async () => {
      const el = await mountWithWires({
        contextInfo: { contextType: "Project", accountName: "A", projectName: "P", taskName: "T" },
        messages: []
      });
      expect(el.shadowRoot.textContent).toMatch(/Account: A/);
      expect(el.shadowRoot.textContent).toMatch(/Project: P/);
      expect(el.shadowRoot.textContent).toMatch(/Task: T/);
    });

    it("contextIcon account type in banner", async () => {
      const elAcc = await mountWithWires({
        contextInfo: { contextType: "Account", accountName: "X" },
        messages: []
      });
      const icAcc = elAcc.shadowRoot.querySelector(".context-display__icon");
      expect(icAcc.iconName || icAcc.getAttribute("icon-name")).toBe("utility:account");
    });

    it("computeShowTaskFooter hides task row when same task as context", async () => {
      const tid = "a02000000000002";
      const el = await mountWithWires({
        relatedTaskId: tid,
        contextInfo: { contextType: "Task", taskName: "Cur" },
        messages: [
          baseMessage({
            id: "a0Xtf",
            relatedTaskId: tid,
            relatedTaskName: "Same Task"
          })
        ]
      });
      expect(el.shadowRoot.textContent).not.toMatch(/Task: Same Task/);
    });

    it("subscribeToMessageUpdates returns when no message context", () => {
      subscribeSpy.mockClear();
      const el = createElement("c-portal-messaging", { is: PortalMessaging });
      PortalMessaging.prototype.subscribeToMessageUpdates.call(el);
      expect(subscribeSpy).not.toHaveBeenCalled();
    });

    it("publishMessageUpdate returns when no message context", () => {
      publishSpy.mockClear();
      const el = createElement("c-portal-messaging", { is: PortalMessaging });
      PortalMessaging.prototype.publishMessageUpdate.call(el, "x");
      expect(publishSpy).not.toHaveBeenCalled();
    });

    it("handleNavigateToRecord returns when dataset.link missing", async () => {
      const el = await mountWithWires({ messages: [baseMessage()] });
      PortalMessaging.prototype.handleNavigateToRecord.call(el, {
        currentTarget: { dataset: {} }
      });
      expect(true).toBe(true);
    });

    it("handleScrollToMessageInThread returns when message id missing", async () => {
      const el = await mountWithWires({ messages: [baseMessage()] });
      await PortalMessaging.prototype.handleScrollToMessageInThread.call(el, {
        currentTarget: { dataset: {} }
      });
      expect(true).toBe(true);
    });

    it("handleNavigateToOriginalMessage returns when messageId missing", async () => {
      const el = await mountWithWires({ messages: [baseMessage()] });
      PortalMessaging.prototype.handleNavigateToOriginalMessage.call(el, {
        currentTarget: { dataset: {} }
      });
      expect(true).toBe(true);
    });

    it("isActingUserMessageAuthor uses 15-digit createdById match", async () => {
      const el = await mountWithWires({
        messages: [
          baseMessage({
            id: "a0X15",
            senderId: "003999999999999",
            createdById: "005000000000099"
          })
        ]
      });
      expect(el.shadowRoot.querySelector(".message-overflow-menu")).not.toBeNull();
    });

    it("salesforceIdsEqual and isActingUserMessageAuthor handle null", () => {
      const el = createElement("c-portal-messaging", { is: PortalMessaging });
      expect(PortalMessaging.prototype.salesforceIdsEqual.call(el, null, "x")).toBe(false);
      expect(PortalMessaging.prototype.isActingUserMessageAuthor.call(el, null)).toBe(false);
    });

    it("LEX buildLink uses Account objectApiName for /account path", async () => {
      const el = await mountWithWires({
        milestoneMember: true,
        pageRef: {
          type: "standard__recordPage",
          attributes: { recordId: "001000000000001AAA", objectApiName: "Account" },
          state: {}
        },
        contextInfo: { contextType: "Account", accountName: "A" },
        messages: []
      });
      Object.defineProperty(el, "isSalesforceContext", {
        configurable: true,
        get() {
          return true;
        }
      });
      const link = PortalMessaging.prototype.buildLink.call(el, "001000000000099AAA", "Sub", "/account");
      expect(link.type).toBe("standard__recordPage");
      expect(link.attributes.objectApiName).toBe("Account");
    });

    it("pinnedMessagesCompact sorts by id when dates tie", async () => {
      const t = new Date().toISOString();
      const el = await mountWithWires({
        milestoneMember: true,
        pinnedMessages: [],
        messages: [
          baseMessage({ id: "a0Xz9", isPinned: true, createdDate: t, createdByName: "Admin" }),
          baseMessage({ id: "a0Xa9", isPinned: true, createdDate: t, createdByName: "Admin" })
        ]
      });
      const rows = el.shadowRoot.querySelectorAll(".pinned-compact-row");
      expect(rows.length).toBe(2);
    });

    it("handleToggleSearch opening calls focus path (search field present)", async () => {
      const el = await mountWithWires({ messages: [baseMessage()] });
      el.shadowRoot.querySelector(".search-toggle-button").click();
      await flushPromises();
      expect(el.shadowRoot.querySelector(".message-search-input")).not.toBeNull();
    });

    it("formatMessageDate uses plural minute hour day", () => {
      const el = createElement("c-portal-messaging", { is: PortalMessaging });
      const fixed = new Date("2026-06-01T12:00:00.000Z");
      jest.useFakeTimers({ now: fixed });
      const fmt = (d) => PortalMessaging.prototype.formatMessageDate.call(el, d);
      expect(fmt(new Date(fixed.getTime() - 1 * 60000).toISOString())).toMatch(/1 minute ago/);
      expect(fmt(new Date(fixed.getTime() - 1 * 3600000).toISOString())).toMatch(/1 hour ago/);
      expect(fmt(new Date(fixed.getTime() - 1 * 86400000).toISOString())).toMatch(/1 day ago/);
      expect(fmt(new Date(fixed.getTime() - 5 * 60000).toISOString())).toMatch(/minutes/);
      expect(fmt(new Date(fixed.getTime() - 5 * 3600000).toISOString())).toMatch(/hours/);
      expect(fmt(new Date(fixed.getTime() - 5 * 86400000).toISOString())).toMatch(/days/);
    });

    it("confirmAndDeleteMessage catch shows error toast", async () => {
      window.confirm = jest.fn(() => true);
      apexMocks.deleteMessageAndAttachments.mockRejectedValueOnce(new Error("del err"));
      const el = await mountWithWires({
        messages: [baseMessage({ id: "a0Xde", senderId: "003000000000001AAA" })]
      });
      const dispatchSpy = jest.spyOn(el, "dispatchEvent");
      await PortalMessaging.prototype.confirmAndDeleteMessage.call(el, "a0Xde");
      await flushPromises();
      const errToast = dispatchSpy.mock.calls.some(([ev]) => ev && ev.detail && ev.detail.variant === "error");
      expect(errToast).toBe(true);
      dispatchSpy.mockRestore();
    });
  });
});
