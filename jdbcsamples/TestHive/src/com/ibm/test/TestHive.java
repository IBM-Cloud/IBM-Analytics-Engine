package com.ibm.test;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.Statement;
 
// CHANGEME1 - change to your cluster's hostname
// CHANGEM2 - change to your cluster's password

// This is a very simple JDBC program to show how to work with Hive on Analytics Engien
public class TestHive {

  public static void main(String[] args) throws Exception {
    Class.forName("org.apache.hive.jdbc.HiveDriver");
    Connection conn = DriverManager.getConnection(
        "jdbc:hive2://chs-<CHANGEME1>-mn003.bi.services.us-south.bluemix.net:8443/;ssl=true;transportMode=http;httpPath=gateway/default/hive", "clsadmin", "<CHANGEME>");
    Statement stmt = conn.createStatement();
    
    try
    {
       // CREATE TABLE
        String createTableDDL = "CREATE TABLE IF NOT EXISTS employee ( eid int, name String) "; 
        PreparedStatement ps1 = conn.prepareStatement(createTableDDL);
        ps1.execute(createTableDDL);
      
        //INSERT INTO TABLE
        PreparedStatement ps2 = conn.prepareStatement("INSERT INTO employee values(700007,'ALUDURM')");
        ps2.execute();
        
        //SELECT FROM TABLE
        PreparedStatement ps = conn.prepareStatement("SELECT * from employee");
        ResultSet rs = ps.executeQuery();
        System.out.println("Table Values");
        while(rs.next()) {
            int id = rs.getInt(1);
            String firstName = rs.getString(2);
            System.out.println("\tRow: " + id + "," + firstName);
        }

        // SHOW TABLES
        String sql = "show tables ";
        System.out.println("Running: " + sql);
        ResultSet res = stmt.executeQuery(sql);
        if (res.next()) {
          System.out.println("\t"+ res.getString(1));
        }
        
        //DROP TABLE
        System.out.println("Dropping table: employee");
        ps = conn.prepareStatement("DROP TABLE employee");
        ps.execute();
 
    }
    finally{
      conn.close();
    }
 
  }
}