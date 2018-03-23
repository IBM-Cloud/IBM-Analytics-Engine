package com.ibm.test;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.util.Properties;

public class TestPhoenix {  

  public static void main(String[] args) throws Exception{
    
      // Phoenix jdbc connection string. Refer to the phoenix endpoint from the cluster
      String phoenix_jdbc_url = "jdbc:phoenix:thin:url=https://chs-mmm-007-mn001.bi.services.us-south.bluemix.net:8443/"
        + "gateway/default/avatica;authentication=BASIC;serialization=PROTOBUF";

      Class.forName("org.apache.phoenix.jdbc.PhoenixDriver");
      Properties props = new Properties();
      props.setProperty("avatica_user", "clsadmin");
      props.setProperty("avatica_password", "yadayada");
      Connection conn=DriverManager.getConnection(phoenix_jdbc_url, props);
      
      //CREATE TABLE
      PreparedStatement ps1 = conn.prepareStatement("CREATE TABLE test1 (id bigint not null,m.fname varchar(50),m.lname varchar(50) CONSTRAINT pk PRIMARY KEY (id))");
      ResultSet rs1 = ps1.executeQuery();

      //UPSERT TABLE - For Hbase, only UPSERTS work
      PreparedStatement ps2 = conn.prepareStatement("UPSERT INTO test1 values(748234,'Aludurm','Ujaridam')");
      ResultSet rs2 = ps2.executeQuery();
      
      //SELECT
      PreparedStatement ps = conn.prepareStatement("SELECT * from test1");
      ResultSet rs = ps.executeQuery();
      System.out.println("Table Values");
      while(rs.next()) {
          int id = rs.getInt(1);
          String firstName = rs.getString(2);
          String lastName = rs.getString(3);
          System.out.println("\tRow: " + id + "," + firstName + ", " + lastName);
      }

  }

}
