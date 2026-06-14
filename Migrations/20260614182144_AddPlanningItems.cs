using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PlannerAPI.Migrations
{
    /// <inheritdoc />
    public partial class AddPlanningItems : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "PlanningItems",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    ProjectId = table.Column<int>(type: "int", nullable: false),
                    ParentId = table.Column<int>(type: "int", nullable: true),
                    Name = table.Column<string>(type: "nvarchar(150)", maxLength: 150, nullable: false),
                    Type = table.Column<int>(type: "int", nullable: false),
                    SortOrder = table.Column<int>(type: "int", nullable: false),
                    WbsCode = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: false),
                    TaskId = table.Column<int>(type: "int", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PlanningItems", x => x.Id);
                    table.ForeignKey(
                        name: "FK_PlanningItems_PlannerTasks_TaskId",
                        column: x => x.TaskId,
                        principalTable: "PlannerTasks",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                    table.ForeignKey(
                        name: "FK_PlanningItems_PlanningItems_ParentId",
                        column: x => x.ParentId,
                        principalTable: "PlanningItems",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_PlanningItems_Projects_ProjectId",
                        column: x => x.ProjectId,
                        principalTable: "Projects",
                        principalColumn: "Id");
                });

            migrationBuilder.CreateIndex(
                name: "IX_PlanningItems_ParentId",
                table: "PlanningItems",
                column: "ParentId");

            migrationBuilder.CreateIndex(
                name: "IX_PlanningItems_ProjectId_ParentId_SortOrder",
                table: "PlanningItems",
                columns: new[] { "ProjectId", "ParentId", "SortOrder" });

            migrationBuilder.CreateIndex(
                name: "IX_PlanningItems_TaskId",
                table: "PlanningItems",
                column: "TaskId",
                unique: true,
                filter: "[TaskId] IS NOT NULL");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "PlanningItems");
        }
    }
}
