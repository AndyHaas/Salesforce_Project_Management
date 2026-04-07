import { createElement } from "lwc";
import TaskHoverCard from "c/taskHoverCard";

function flushPromises() {
  return Promise.resolve().then(() => Promise.resolve());
}

function teardown() {
  while (document.body.firstChild) {
    document.body.removeChild(document.body.firstChild);
  }
}

describe("c-task-hover-card", () => {
  afterEach(teardown);

  it("mounts with hover field data for template wiring", async () => {
    const el = createElement("c-task-hover-card", { is: TaskHoverCard });
    el.hoverFields = [
      { apiName: "Name", label: "Name", value: "Sample Task" }
    ];
    el.taskStatus = "In Progress";
    document.body.appendChild(el);
    await flushPromises();

    expect(el.shadowRoot).not.toBeNull();
  });
});
