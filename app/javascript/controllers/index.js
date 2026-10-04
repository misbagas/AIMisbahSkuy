// Import and register all your controllers from the importmap via controllers/**/*_controller
import { application } from "./application"
import RenameProjectController from "./rename_project_controller"
import SidebarController from "./sidebar_controller"
import TaskComposerController from "./task_composer_controller"

application.register("sidebar", SidebarController)
application.register("task-composer", TaskComposerController)
application.register("rename-project", RenameProjectController)
