using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PlannerAPI.Migrations
{
    /// <inheritdoc />
    public partial class AddPlanningVersions : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "PlanningVersions",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    ProjectId = table.Column<int>(type: "int", nullable: false),
                    VersionNumber = table.Column<int>(type: "int", nullable: false),
                    Name = table.Column<string>(type: "nvarchar(150)", maxLength: 150, nullable: false),
                    Description = table.Column<string>(type: "nvarchar(1000)", maxLength: 1000, nullable: true),
                    CreatedBy = table.Column<string>(type: "nvarchar(150)", maxLength: 150, nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "datetime2", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PlanningVersions", x => x.Id);
                    table.ForeignKey(
                        name: "FK_PlanningVersions_Projects_ProjectId",
                        column: x => x.ProjectId,
                        principalTable: "Projects",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "PlanningVersionAssignments",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    PlanningVersionId = table.Column<int>(type: "int", nullable: false),
                    OriginalAssignmentId = table.Column<int>(type: "int", nullable: false),
                    OriginalTaskId = table.Column<int>(type: "int", nullable: false),
                    OriginalResourceId = table.Column<int>(type: "int", nullable: true),
                    ResourceName = table.Column<string>(type: "nvarchar(150)", maxLength: 150, nullable: true),
                    OriginalResourceGroupId = table.Column<int>(type: "int", nullable: true),
                    ResourceGroupName = table.Column<string>(type: "nvarchar(150)", maxLength: 150, nullable: true),
                    WorkloadHours = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: false),
                    AllocationPercent = table.Column<int>(type: "int", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PlanningVersionAssignments", x => x.Id);
                    table.ForeignKey(
                        name: "FK_PlanningVersionAssignments_PlanningVersions_PlanningVersionId",
                        column: x => x.PlanningVersionId,
                        principalTable: "PlanningVersions",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "PlanningVersionCalendars",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    PlanningVersionId = table.Column<int>(type: "int", nullable: false),
                    WorkMonday = table.Column<bool>(type: "bit", nullable: false),
                    WorkTuesday = table.Column<bool>(type: "bit", nullable: false),
                    WorkWednesday = table.Column<bool>(type: "bit", nullable: false),
                    WorkThursday = table.Column<bool>(type: "bit", nullable: false),
                    WorkFriday = table.Column<bool>(type: "bit", nullable: false),
                    WorkSaturday = table.Column<bool>(type: "bit", nullable: false),
                    WorkSunday = table.Column<bool>(type: "bit", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PlanningVersionCalendars", x => x.Id);
                    table.ForeignKey(
                        name: "FK_PlanningVersionCalendars_PlanningVersions_PlanningVersionId",
                        column: x => x.PlanningVersionId,
                        principalTable: "PlanningVersions",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "PlanningVersionDependencies",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    PlanningVersionId = table.Column<int>(type: "int", nullable: false),
                    OriginalDependencyId = table.Column<int>(type: "int", nullable: false),
                    OriginalPredecessorTaskId = table.Column<int>(type: "int", nullable: false),
                    OriginalSuccessorTaskId = table.Column<int>(type: "int", nullable: false),
                    Type = table.Column<string>(type: "nvarchar(2)", maxLength: 2, nullable: false),
                    OffsetDays = table.Column<int>(type: "int", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PlanningVersionDependencies", x => x.Id);
                    table.ForeignKey(
                        name: "FK_PlanningVersionDependencies_PlanningVersions_PlanningVersionId",
                        column: x => x.PlanningVersionId,
                        principalTable: "PlanningVersions",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "PlanningVersionItems",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    PlanningVersionId = table.Column<int>(type: "int", nullable: false),
                    OriginalPlanningItemId = table.Column<int>(type: "int", nullable: false),
                    OriginalParentId = table.Column<int>(type: "int", nullable: true),
                    Name = table.Column<string>(type: "nvarchar(150)", maxLength: 150, nullable: false),
                    Type = table.Column<int>(type: "int", nullable: false),
                    SortOrder = table.Column<int>(type: "int", nullable: false),
                    WbsCode = table.Column<string>(type: "nvarchar(50)", maxLength: 50, nullable: false),
                    OriginalTaskId = table.Column<int>(type: "int", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PlanningVersionItems", x => x.Id);
                    table.ForeignKey(
                        name: "FK_PlanningVersionItems_PlanningVersions_PlanningVersionId",
                        column: x => x.PlanningVersionId,
                        principalTable: "PlanningVersions",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "PlanningVersionTasks",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    PlanningVersionId = table.Column<int>(type: "int", nullable: false),
                    OriginalTaskId = table.Column<int>(type: "int", nullable: false),
                    Title = table.Column<string>(type: "nvarchar(100)", maxLength: 100, nullable: false),
                    Description = table.Column<string>(type: "nvarchar(500)", maxLength: 500, nullable: true),
                    StartDate = table.Column<DateTime>(type: "datetime2", nullable: true),
                    EndDate = table.Column<DateTime>(type: "datetime2", nullable: true),
                    Duration = table.Column<int>(type: "int", nullable: true),
                    ProgressPercent = table.Column<int>(type: "int", nullable: false),
                    IsDone = table.Column<bool>(type: "bit", nullable: false),
                    ActualDuration = table.Column<int>(type: "int", nullable: true),
                    AssignedResourcesCount = table.Column<int>(type: "int", nullable: true),
                    WorkloadHours = table.Column<decimal>(type: "decimal(18,2)", precision: 18, scale: 2, nullable: true),
                    EarlyStart = table.Column<DateTime>(type: "datetime2", nullable: true),
                    EarlyFinish = table.Column<DateTime>(type: "datetime2", nullable: true),
                    LateStart = table.Column<DateTime>(type: "datetime2", nullable: true),
                    LateFinish = table.Column<DateTime>(type: "datetime2", nullable: true),
                    TotalFloat = table.Column<int>(type: "int", nullable: true),
                    IsCritical = table.Column<bool>(type: "bit", nullable: false),
                    Deadline = table.Column<DateTime>(type: "datetime2", nullable: true),
                    DelayDays = table.Column<int>(type: "int", nullable: false),
                    IsLate = table.Column<bool>(type: "bit", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PlanningVersionTasks", x => x.Id);
                    table.ForeignKey(
                        name: "FK_PlanningVersionTasks_PlanningVersions_PlanningVersionId",
                        column: x => x.PlanningVersionId,
                        principalTable: "PlanningVersions",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "PlanningVersionCalendarExceptions",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    PlanningVersionCalendarId = table.Column<int>(type: "int", nullable: false),
                    Date = table.Column<DateTime>(type: "datetime2", nullable: false),
                    Label = table.Column<string>(type: "nvarchar(150)", maxLength: 150, nullable: false),
                    IsWorkingDay = table.Column<bool>(type: "bit", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PlanningVersionCalendarExceptions", x => x.Id);
                    table.ForeignKey(
                        name: "FK_PlanningVersionCalendarExceptions_PlanningVersionCalendars_PlanningVersionCalendarId",
                        column: x => x.PlanningVersionCalendarId,
                        principalTable: "PlanningVersionCalendars",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "PlanningVersionCalendarPeriods",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    PlanningVersionCalendarId = table.Column<int>(type: "int", nullable: false),
                    StartDate = table.Column<DateTime>(type: "datetime2", nullable: false),
                    EndDate = table.Column<DateTime>(type: "datetime2", nullable: false),
                    Label = table.Column<string>(type: "nvarchar(150)", maxLength: 150, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PlanningVersionCalendarPeriods", x => x.Id);
                    table.ForeignKey(
                        name: "FK_PlanningVersionCalendarPeriods_PlanningVersionCalendars_PlanningVersionCalendarId",
                        column: x => x.PlanningVersionCalendarId,
                        principalTable: "PlanningVersionCalendars",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_PlanningVersionAssignments_PlanningVersionId_OriginalAssignmentId",
                table: "PlanningVersionAssignments",
                columns: new[] { "PlanningVersionId", "OriginalAssignmentId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_PlanningVersionCalendarExceptions_PlanningVersionCalendarId_Date",
                table: "PlanningVersionCalendarExceptions",
                columns: new[] { "PlanningVersionCalendarId", "Date" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_PlanningVersionCalendarPeriods_PlanningVersionCalendarId_StartDate_EndDate",
                table: "PlanningVersionCalendarPeriods",
                columns: new[] { "PlanningVersionCalendarId", "StartDate", "EndDate" });

            migrationBuilder.CreateIndex(
                name: "IX_PlanningVersionCalendars_PlanningVersionId",
                table: "PlanningVersionCalendars",
                column: "PlanningVersionId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_PlanningVersionDependencies_PlanningVersionId_OriginalDependencyId",
                table: "PlanningVersionDependencies",
                columns: new[] { "PlanningVersionId", "OriginalDependencyId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_PlanningVersionDependencies_PlanningVersionId_OriginalPredecessorTaskId_OriginalSuccessorTaskId_Type",
                table: "PlanningVersionDependencies",
                columns: new[] { "PlanningVersionId", "OriginalPredecessorTaskId", "OriginalSuccessorTaskId", "Type" });

            migrationBuilder.CreateIndex(
                name: "IX_PlanningVersionItems_PlanningVersionId_OriginalParentId_SortOrder",
                table: "PlanningVersionItems",
                columns: new[] { "PlanningVersionId", "OriginalParentId", "SortOrder" });

            migrationBuilder.CreateIndex(
                name: "IX_PlanningVersionItems_PlanningVersionId_OriginalPlanningItemId",
                table: "PlanningVersionItems",
                columns: new[] { "PlanningVersionId", "OriginalPlanningItemId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_PlanningVersions_ProjectId_CreatedAt",
                table: "PlanningVersions",
                columns: new[] { "ProjectId", "CreatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_PlanningVersions_ProjectId_VersionNumber",
                table: "PlanningVersions",
                columns: new[] { "ProjectId", "VersionNumber" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_PlanningVersionTasks_PlanningVersionId_OriginalTaskId",
                table: "PlanningVersionTasks",
                columns: new[] { "PlanningVersionId", "OriginalTaskId" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "PlanningVersionAssignments");

            migrationBuilder.DropTable(
                name: "PlanningVersionCalendarExceptions");

            migrationBuilder.DropTable(
                name: "PlanningVersionCalendarPeriods");

            migrationBuilder.DropTable(
                name: "PlanningVersionDependencies");

            migrationBuilder.DropTable(
                name: "PlanningVersionItems");

            migrationBuilder.DropTable(
                name: "PlanningVersionTasks");

            migrationBuilder.DropTable(
                name: "PlanningVersionCalendars");

            migrationBuilder.DropTable(
                name: "PlanningVersions");
        }
    }
}
