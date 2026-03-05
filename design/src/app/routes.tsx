import { createBrowserRouter } from "react-router";
import { Home } from "./pages/Home";
import { Evolution } from "./pages/Evolution";
import { Battle } from "./pages/Battle";
import { Share } from "./pages/Share";
import { Widget } from "./pages/Widget";

export const router = createBrowserRouter([
  {
    path: "/",
    Component: Home,
  },
  {
    path: "/evolution",
    Component: Evolution,
  },
  {
    path: "/battle",
    Component: Battle,
  },
  {
    path: "/share",
    Component: Share,
  },
  {
    path: "/widget",
    Component: Widget,
  },
]);
