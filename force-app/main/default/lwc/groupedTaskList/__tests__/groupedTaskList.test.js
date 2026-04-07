import { createElement } from "lwc";
import GroupedTaskList from "c/groupedTaskList";

function flushPromises() {
  return Promise.resolve().then(() => Promise.resolve());
}

function teardown() {
  while (document.body.firstChild) {
    document.body.removeChild(document.body.firstChild);
  }
}

describe("c-grouped-task-list", () => {
  afterEach(teardown);

  it("renders root lightning-card with Tasks title", async () => {
    const el = createElement("c-grouped-task-list", { is: GroupedTaskList });
    document.body.appendChild(el);
    await flushPromises();

    const card = el.shadowRoot.querySelector("lightning-card");
    expect(card).not.toBeNull();
    expect(card.title).toBe("Tasks");
  });
});
