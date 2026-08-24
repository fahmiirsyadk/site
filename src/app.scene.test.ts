import { describe, test } from "vitest";

import type { Model as RuntimeModel } from "purescript/App.Update/index.ts";
import type { RawMessage as RuntimeMessage } from "purescript/App.Wire.Message/index.ts";
import { initInput, updateInput } from "purescript/App.Update/index.ts";
import { view } from "purescript/App.View/index.ts";

import type { HtmlBuilder } from "foldkit/html";
import type { Document } from "foldkit/html";
import * as Scene from "foldkit/scene";

import { commandImpl } from "./platform/browser/foldkit-command";
import {
  hollowMark,
  randomScribble,
  seaShader,
} from "./platform/browser/foldkit-mount";

const update = (model: RuntimeModel, message: RuntimeMessage) => {
  const result = updateInput({ model, message });
  return [result.model, result.commands.map(commandImpl)] as const;
};

const render = (model: RuntimeModel, builder: HtmlBuilder<RuntimeMessage>) =>
  view(model, builder) as unknown as Document;

const message = (_tag: string): RuntimeMessage => ({
  _tag,
  requestTag: "",
  requestUrl: "",
  requestHref: "",
  url: "",
  theme: "",
  contributions: 0,
  followers: 0,
  levels: [],
});

const resolveHomeMounts = Scene.Mount.resolveAll(
  [hollowMark, message("CompletedMountHollowMark")],
  [randomScribble, message("CompletedMountRandomScribble")],
  [seaShader, message("CompletedMountSeaShader")],
);

const resolvePageMounts = Scene.Mount.resolveAll(
  [hollowMark, message("CompletedMountHollowMark")],
  [seaShader, message("CompletedMountSeaShader")],
);

describe("application view integration", () => {
  test("renders shared navigation and published thought content on the home page", () => {
    Scene.scene(
      { update, view: render },
      Scene.given(initInput({ path: "/" }).model),
      Scene.expect(
        Scene.role("navigation", { name: "Primary navigation" }),
      ).toExist(),
      Scene.expect(Scene.role("link", { name: "thought" })).toHaveAttr(
        "href",
        "/thought/",
      ),
      Scene.expect(Scene.text("Chaotic pendulum")).toExist(),
      resolveHomeMounts,
    );
  });

  test("keeps shared chrome while rendering the thought route", () => {
    Scene.scene(
      { update, view: render },
      Scene.given(initInput({ path: "/thought/" }).model),
      Scene.expect(
        Scene.role("img", { name: "Faah split lunar sphere" }),
      ).toExist(),
      Scene.expect(Scene.role("heading", { name: "thought" })).toExist(),
      Scene.expect(Scene.role("link", { name: "thought" })).toHaveAttr(
        "aria-current",
        "page",
      ),
      Scene.expect(Scene.text("Chaotic pendulum")).toExist(),
      resolvePageMounts,
    );
  });

  test("preserves the monochrome lab interaction state on the lab route", () => {
    Scene.scene(
      { update, view: render },
      Scene.given(initInput({ path: "/lab/" }).model),
      Scene.expect(Scene.role("heading", { name: "lab" })).toExist(),
      Scene.expect(
        Scene.role("img", { name: "Faah split lunar sphere" }),
      ).toHaveAttr("data-lab-interaction", "hovered"),
      Scene.expect(Scene.selector("#sea-footer")).toHaveAttr(
        "data-lab-interaction",
        "hovered",
      ),
      resolvePageMounts,
    );
  });
});
