/**
 * Experience Cloud project route: resolves Project__c Id and renders unified file manager.
 */
import { LightningElement, track, wire } from "lwc";
import { CurrentPageReference } from "lightning/navigation";

export default class ProjectDetail extends LightningElement {
  @track projectId;

  @wire(CurrentPageReference)
  resolvePageReference(pageRef) {
    if (!pageRef) {
      return;
    }

    const { attributes = {}, state = {} } = pageRef;
    let projectId = state.recordId || attributes.recordId || state.c__projectId;

    if (!projectId && typeof window !== "undefined") {
      let pathname = window.location.pathname || "";
      pathname = pathname.replace(/^\/s/, "");
      const parts = pathname.split("/").filter(Boolean);
      const projectIdx = parts.indexOf("project");
      if (projectIdx !== -1 && projectIdx + 1 < parts.length) {
        projectId = decodeURIComponent(parts[projectIdx + 1]);
      }
    }

    if (projectId && projectId !== this.projectId) {
      this.projectId = projectId;
    }
  }
}
