import { createElement } from "lwc";
import { registerTestWireAdapter } from "@salesforce/sfdx-lwc-jest";
import { CurrentPageReference } from "lightning/navigation";
import ProjectDetail from "c/projectDetail";

jest.mock("c/fileManager", () => {
  const { LightningElement } = require("lwc");
  return {
    __esModule: true,
    default: class extends LightningElement {}
  };
});

const pageReferenceAdapter = registerTestWireAdapter(CurrentPageReference);

function flushPromises() {
  return Promise.resolve().then(() => Promise.resolve());
}

function setPathname(pathname) {
  delete window.location;
  window.location = { pathname, href: `https://example.com${pathname}` };
}

describe("c-project-detail", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    setPathname("/");
  });

  it("shows fallback when no project id is resolved", async () => {
    const el = createElement("c-project-detail", { is: ProjectDetail });
    document.body.appendChild(el);
    pageReferenceAdapter.emit({ attributes: {}, state: {} });
    await flushPromises();

    const msg = el.shadowRoot.querySelector(".slds-text-body_small");
    expect(msg?.textContent?.trim()).toBe("No project id provided in URL.");
    expect(el.shadowRoot.querySelector("c-file-manager")).toBeNull();
  });

  it("does not update when pageRef is falsy", async () => {
    const el = createElement("c-project-detail", { is: ProjectDetail });
    document.body.appendChild(el);
    pageReferenceAdapter.emit(undefined);
    await flushPromises();

    expect(el.shadowRoot.querySelector("c-file-manager")).toBeNull();
  });

  it("sets projectId from state.recordId and renders file manager", async () => {
    const el = createElement("c-project-detail", { is: ProjectDetail });
    document.body.appendChild(el);
    pageReferenceAdapter.emit({
      attributes: {},
      state: { recordId: "a01000000000001AAA" }
    });
    await flushPromises();

    const fm = el.shadowRoot.querySelector("c-file-manager");
    expect(fm).not.toBeNull();
    expect(fm.recordId).toBe("a01000000000001AAA");
  });

  it("prefers state.recordId over attributes.recordId", async () => {
    const el = createElement("c-project-detail", { is: ProjectDetail });
    document.body.appendChild(el);
    pageReferenceAdapter.emit({
      attributes: { recordId: "a02000000000002AAA" },
      state: { recordId: "a01000000000001AAA" }
    });
    await flushPromises();

    expect(el.shadowRoot.querySelector("c-file-manager").recordId).toBe("a01000000000001AAA");
  });

  it("uses attributes.recordId when state has no recordId", async () => {
    const el = createElement("c-project-detail", { is: ProjectDetail });
    document.body.appendChild(el);
    pageReferenceAdapter.emit({
      attributes: { recordId: "a03000000000003AAA" },
      state: {}
    });
    await flushPromises();

    expect(el.shadowRoot.querySelector("c-file-manager").recordId).toBe("a03000000000003AAA");
  });

  it("uses state.c__projectId when record ids absent", async () => {
    const el = createElement("c-project-detail", { is: ProjectDetail });
    document.body.appendChild(el);
    pageReferenceAdapter.emit({
      attributes: {},
      state: { c__projectId: "a04000000000004AAA" }
    });
    await flushPromises();

    expect(el.shadowRoot.querySelector("c-file-manager").recordId).toBe("a04000000000004AAA");
  });

  it("parses project id from pathname after /s prefix", async () => {
    setPathname("/s/acme/project/a05000000000005AAA/extra");
    const el = createElement("c-project-detail", { is: ProjectDetail });
    document.body.appendChild(el);
    pageReferenceAdapter.emit({ attributes: {}, state: {} });
    await flushPromises();

    expect(el.shadowRoot.querySelector("c-file-manager").recordId).toBe("a05000000000005AAA");
  });

  it("parses project id from pathname without /s prefix", async () => {
    setPathname("/portal/project/a06000000000006AAA");
    const el = createElement("c-project-detail", { is: ProjectDetail });
    document.body.appendChild(el);
    pageReferenceAdapter.emit({ attributes: {}, state: {} });
    await flushPromises();

    expect(el.shadowRoot.querySelector("c-file-manager").recordId).toBe("a06000000000006AAA");
  });

  it("decodes URI-encoded segment from pathname", async () => {
    setPathname("/project/a07%2F00000000007AAA");
    const el = createElement("c-project-detail", { is: ProjectDetail });
    document.body.appendChild(el);
    pageReferenceAdapter.emit({ attributes: {}, state: {} });
    await flushPromises();

    expect(el.shadowRoot.querySelector("c-file-manager").recordId).toBe("a07/00000000007AAA");
  });

  it("does not parse pathname when project segment has no following part", async () => {
    setPathname("/foo/project");
    const el = createElement("c-project-detail", { is: ProjectDetail });
    document.body.appendChild(el);
    pageReferenceAdapter.emit({ attributes: {}, state: {} });
    await flushPromises();

    expect(el.shadowRoot.querySelector("c-file-manager")).toBeNull();
  });

  it("ignores wire update when projectId is unchanged", async () => {
    const el = createElement("c-project-detail", { is: ProjectDetail });
    document.body.appendChild(el);
    const ref = { attributes: {}, state: { recordId: "a08000000000008AAA" } };
    pageReferenceAdapter.emit(ref);
    await flushPromises();
    pageReferenceAdapter.emit({ ...ref });
    await flushPromises();

    expect(el.shadowRoot.querySelector("c-file-manager").recordId).toBe("a08000000000008AAA");
  });
});
