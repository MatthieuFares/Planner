using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PlannerAPI.Migrations
{
    /// <inheritdoc />
    public partial class AddTaskFieldsAndCriticalPath : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "ActualDuration",
                table: "PlannerTasks",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "AssignedResourcesCount",
                table: "PlannerTasks",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "IsCritical",
                table: "PlannerTasks",
                type: "bit",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<decimal>(
                name: "WorkloadHours",
                table: "PlannerTasks",
                type: "decimal(18,2)",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "ActualDuration",
                table: "PlannerTasks");

            migrationBuilder.DropColumn(
                name: "AssignedResourcesCount",
                table: "PlannerTasks");

            migrationBuilder.DropColumn(
                name: "IsCritical",
                table: "PlannerTasks");

            migrationBuilder.DropColumn(
                name: "WorkloadHours",
                table: "PlannerTasks");
        }
    }
}
