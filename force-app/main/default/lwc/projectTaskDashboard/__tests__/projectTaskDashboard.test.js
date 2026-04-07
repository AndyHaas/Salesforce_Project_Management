import { createElement } from "lwc";
import ProjectTaskDashboard from "c/projectTaskDashboard";

function flushPromises() {
  return Promise.resolve().then(() => Promise.resolve());
}

function teardown() {
  while (document.body.firstChild) {
    document.body.removeChild(document.body.firstChild);
  }
}

describe("c-project-task-dashboard", () => {
  afterEach(teardown);

  it("renders Project Task Dashboard card", async () => {
    const el = createElement("c-project-task-dashboard", {
      is: ProjectTaskDashboard
    });
    document.body.appendChild(el);
    await flushPromises();

    const card = el.shadowRoot.querySelector("lightning-card");
    expect(card).not.toBeNull();
    expect(card.title).toBe("Project Task Dashboard");
  });
});
