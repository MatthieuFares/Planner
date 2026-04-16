using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PlannerAPI.Migrations
{
    /// <inheritdoc />
    public partial class V1 : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_TaskDependencies_Tasks_PredecessorId",
                table: "TaskDependencies");

            migrationBuilder.DropForeignKey(
                name: "FK_TaskDependencies_Tasks_SuccessorId",
                table: "TaskDependencies");

            migrationBuilder.DropForeignKey(
                name: "FK_Tasks_Projects_ProjectId",
                table: "Tasks");

            migrationBuilder.DropPrimaryKey(
                name: "PK_Tasks",
                table: "Tasks");

            migrationBuilder.RenameTable(
                name: "Tasks",
                newName: "PlannerTasks");

            migrationBuilder.RenameIndex(
                name: "IX_Tasks_ProjectId",
                table: "PlannerTasks",
                newName: "IX_PlannerTasks_ProjectId");

            migrationBuilder.AddPrimaryKey(
                name: "PK_PlannerTasks",
                table: "PlannerTasks",
                column: "Id");

            migrationBuilder.AddForeignKey(
                name: "FK_PlannerTasks_Projects_ProjectId",
                table: "PlannerTasks",
                column: "ProjectId",
                principalTable: "Projects",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);

            migrationBuilder.AddForeignKey(
                name: "FK_TaskDependencies_PlannerTasks_PredecessorId",
                table: "TaskDependencies",
                column: "PredecessorId",
                principalTable: "PlannerTasks",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_TaskDependencies_PlannerTasks_SuccessorId",
                table: "TaskDependencies",
                column: "SuccessorId",
                principalTable: "PlannerTasks",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_PlannerTasks_Projects_ProjectId",
                table: "PlannerTasks");

            migrationBuilder.DropForeignKey(
                name: "FK_TaskDependencies_PlannerTasks_PredecessorId",
                table: "TaskDependencies");

            migrationBuilder.DropForeignKey(
                name: "FK_TaskDependencies_PlannerTasks_SuccessorId",
                table: "TaskDependencies");

            migrationBuilder.DropPrimaryKey(
                name: "PK_PlannerTasks",
                table: "PlannerTasks");

            migrationBuilder.RenameTable(
                name: "PlannerTasks",
                newName: "Tasks");

            migrationBuilder.RenameIndex(
                name: "IX_PlannerTasks_ProjectId",
                table: "Tasks",
                newName: "IX_Tasks_ProjectId");

            migrationBuilder.AddPrimaryKey(
                name: "PK_Tasks",
                table: "Tasks",
                column: "Id");

            migrationBuilder.AddForeignKey(
                name: "FK_TaskDependencies_Tasks_PredecessorId",
                table: "TaskDependencies",
                column: "PredecessorId",
                principalTable: "Tasks",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_TaskDependencies_Tasks_SuccessorId",
                table: "TaskDependencies",
                column: "SuccessorId",
                principalTable: "Tasks",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);

            migrationBuilder.AddForeignKey(
                name: "FK_Tasks_Projects_ProjectId",
                table: "Tasks",
                column: "ProjectId",
                principalTable: "Projects",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);
        }
    }
}
