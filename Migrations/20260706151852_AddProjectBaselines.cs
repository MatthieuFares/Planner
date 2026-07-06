using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PlannerAPI.Migrations
{
    /// <inheritdoc />
    public partial class AddProjectBaselines : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "ProjectBaselines",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    ProjectId = table.Column<int>(type: "int", nullable: false),
                    Name = table.Column<string>(type: "nvarchar(450)", nullable: false),
                    Description = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false),
                    IsActive = table.Column<bool>(type: "bit", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ProjectBaselines", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ProjectBaselines_Projects_ProjectId",
                        column: x => x.ProjectId,
                        principalTable: "Projects",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "ProjectBaselineTasks",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    ProjectBaselineId = table.Column<int>(type: "int", nullable: false),
                    TaskId = table.Column<int>(type: "int", nullable: false),
                    TaskTitle = table.Column<string>(type: "nvarchar(max)", nullable: false),
                    WbsCode = table.Column<string>(type: "nvarchar(max)", nullable: true),
                    StartDate = table.Column<DateTime>(type: "datetime2", nullable: true),
                    EndDate = table.Column<DateTime>(type: "datetime2", nullable: true),
                    Duration = table.Column<int>(type: "int", nullable: false),
                    ProgressPercent = table.Column<int>(type: "int", nullable: false),
                    Deadline = table.Column<DateTime>(type: "datetime2", nullable: true),
                    TotalFloat = table.Column<int>(type: "int", nullable: false),
                    IsCritical = table.Column<bool>(type: "bit", nullable: false),
                    IsLate = table.Column<bool>(type: "bit", nullable: false),
                    DelayDays = table.Column<int>(type: "int", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ProjectBaselineTasks", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ProjectBaselineTasks_ProjectBaselines_ProjectBaselineId",
                        column: x => x.ProjectBaselineId,
                        principalTable: "ProjectBaselines",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_ProjectBaselines_ProjectId_Name",
                table: "ProjectBaselines",
                columns: new[] { "ProjectId", "Name" });

            migrationBuilder.CreateIndex(
                name: "IX_ProjectBaselineTasks_ProjectBaselineId_TaskId",
                table: "ProjectBaselineTasks",
                columns: new[] { "ProjectBaselineId", "TaskId" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "ProjectBaselineTasks");

            migrationBuilder.DropTable(
                name: "ProjectBaselines");
        }
    }
}
