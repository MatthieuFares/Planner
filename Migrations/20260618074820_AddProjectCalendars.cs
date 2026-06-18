using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PlannerAPI.Migrations
{
    /// <inheritdoc />
    public partial class AddProjectCalendars : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "ProjectCalendars",
                columns: table => new
                {
                    Id = table.Column<int>(type: "int", nullable: false)
                        .Annotation("SqlServer:Identity", "1, 1"),
                    ProjectId = table.Column<int>(type: "int", nullable: false),
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
                    table.PrimaryKey("PK_ProjectCalendars", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ProjectCalendars_Projects_ProjectId",
                        column: x => x.ProjectId,
                        principalTable: "Projects",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_ProjectCalendars_ProjectId",
                table: "ProjectCalendars",
                column: "ProjectId",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "ProjectCalendars");
        }
    }
}
