using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PlannerAPI.Migrations
{
    /// <inheritdoc />
    public partial class AddCanCreateProjects : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "CanCreateProjects",
                table: "AspNetUsers",
                type: "bit",
                nullable: false,
                defaultValue: false);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "CanCreateProjects",
                table: "AspNetUsers");
        }
    }
}
